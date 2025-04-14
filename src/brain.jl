Base.@kwdef mutable struct AIBrain
    memory::AbstractString  = "" # summary of the past query
    history::Dict = Dict("ask" => [], "ans" => []) # conversation history
    prompt::AbstractString  = ""
    api::AbstractString
    stream::Bool=false # if the model returns the stream response
    timeout::Int = 10 # set the timeout for the http request
    model::AbstractString = "gemini-2.0-flash" # the model
    DRG::AbstractString = "" # support in the future
end

(m::AIBrain)( question::AbstractString ) = begin
    headers = Dict("Content-Type" => "application/json")
    body = JSON3.write(Dict("contents" => Dict("parts" => [Dict("text" => m.DRG * "\n" * m.memory * "\n" *  m.prompt * "\n" * question)])))
    url = "https://generativelanguage.googleapis.com/v1beta/models/$(m.model):generateContent?key=$(m.api)"
    if !m.stream
        resp = HTTP.post(url,body=body, headers=headers, timeout=m.timeout)
        if resp.status == 200
            try
                text = JSON3.read(resp.body)[:candidates][1][:content][:parts][1]["text"]
                m.memory *= "ask: $(question) \n ans: $(text) \n"
                push!(m.history["ask"], question)
                push!(m.history["ans"], text)
                @async checkMemory!(m)
                return text |> Markdown.parse # show in the terminal
            catch error
                return "respond: f(JSON3.read(resp.body)[:candidates][1][:finishReason]), you may toggle the request limitation"
            end
        else
            return "respond code: $(resp.status)🔗🚫"
        end
    else

        ##########################
        # for streaming response #
        ##########################

        m.memory *= "ask: $(question) \n"
        push!(m.history["ask"], question)
        url = "https://generativelanguage.googleapis.com/v1beta/models/$(m.model):streamGenerateContent?alt=sse&key=$(m.api)"
        channel = Channel{String}(3000)
        channel2 = Channel{String}(3000)
        @async HTTP.open(:post, url, headers=headers, timeout=m.timeout) do io
            write(io, body)
            HTTP.closewrite(io)
            HTTP.startread(io)
            isdone = false
            while !eof(io)
                chunk = String(readavailable(io))
                lines = String.(filter(!isempty, split(chunk, "\n")))
                for line in lines
                    if startswith(line, "data: ")
                        data = JSON3.read(replace(line, r"^data: " => ""))
                        currentText = data[:candidates][1][:content][:parts][1]["text"]
                        push!(channel,currentText)
                        push!(channel2,currentText)
                    end
                end
            end
            HTTP.closeread(io)
            isopen(channel) && close(channel);
            isopen(channel2) && close(channel2);
        end
        showStreamStringFromChannel(channel) # show in the terminal
        streamToMemory(m,channel2)
        @async checkMemory!(m)
    end;
end



"""
for stream mode, displays a streaming response from the channel, updating the display in terminal with each chunk of text received.
"""
function showStreamStringFromChannel(channel::Channel)
    first_text = take!(channel)
    response = first_text
    println()
    print("\e[32m¬ \e[0m")
    print("\033[s")
    print(first_text)
    for chunk in channel
        print("\033[u\033[s")
        response *= chunk
        sleep(0.01)
        display(Markdown.parse(response))
    end
end


"""
for stream mode, take string from the channel, convert to markdown, and save as `memory` context
"""
function streamToMemory(m::AIBrain,channel::Channel)
    first_text = take!(channel)
    response = first_text

    m.memory *= "ans: $(response)"
    cache = "ans: $(response)"

    for chunk in channel
        m.memory *= "$(chunk)"
        cache *= "$(chunk)"
    end
    push!(m.history["ans"], cache)
end

"""
optimalize the `memory text`, when the memory words length exceeds 3000 words,  summary it into 300 words
"""
function checkMemory!(m::AIBrain,L = 3000)
    if length(m.memory) > L
        tmpBrain = AIBrain(api=AI_API_KEY,prompt = "summary below into 300 words:")
        m.memory = tmpBrain( m.memory) |> string;
    end
    return nothing
end;

MD = Markdown.parse
Base.show(io::IO, ::MIME"text/plain", m::AIBrain) = begin
    MD("""
$(m.model * " with API " * m.api)

\n for more \n
- memory: $(length(m.memory)) words
- history:  $(length(m.history["ans"])) conversation
- prompt: $(m.prompt)
- DRG: not supported yet
""") |> show
end

