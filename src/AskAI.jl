module AskAI
using HTTP, JSON3, Markdown

include("brain.jl")


######################################
# check for the required AI_API_KEY  #
######################################
if haskey(ENV, "AI_API_KEY")
    println("AI_API_KEY is set to $(ENV["AI_API_KEY"])")
    AI_API_KEY = ENV["AI_API_KEY"]
else
    msg = """
API_KEY is needed. please set it as in environment variable:

```julia
ENV["AI_API_KEY"]="1234567890abcdef1234567890abcdef"
```

or set it through function `setapi()`
```julia
setapi("1234567890abcdef1234567890abcdef")

```
"""
    AI_API_KEY = ""
    display(Markdown.parse(msg))
end

"""
set the API_KEY
```julia
setapi("1234567890abcdef1234567890abcdef")
```
"""
setapi(api::AbstractString) = global AI_API_KEY = api


prompt_to_get_code = "if the answer contains code, only output the raw code in julia"
Brain = AIBrain(api=AI_API_KEY, prompt = prompt_to_get_code )


"""
Reset the AskAI, it will remove the conversation history, memory, prompt... and everything as default defined
```julia
AskAI.reset()
```
"""
function reset()
   global Brain = AIBrain(api=AI_API_KEY, prompt = prompt_to_get_code )
end


"""
get the answer from the AI
## example
```julia
@ai "fit a linear model"
# or you can concatenate your question
@ai "fit a" + "linear model"
```
"""
macro ai(expr)
    if isa(expr,String)
        return  :(Brain($expr))
    end

    # Create a list to hold the concatenated parts
    parts = []

    # Iterate over the arguments of the expression
    for arg in expr.args
        # Push each argument to the parts list
        push!(parts, esc(arg))
    end

    # Create the expression to call f with the concatenated string
    return :(Brain(string($(Expr(:call, Symbol("string"), parts...)))))
end


"""
execute the string as code

```julia
"1 + 1" |> AskAI.exe

(@ai "1 + 1") |> AskAI.exe
```
"""
exe(x) = include_string(Main.playground,replace(string(x), "```julia" => "", "```" => ""))


"""
similar to `@ai`,

send the question to AI but @AI perform the code directly and only return the result, or error :(


the conversation history will stored in the `AskAI.Brain.history`
## example:
```julia
@AI "tell me the current time, used the package you need"
```
"""
macro AI(expr)
    if !isdefined(Main, :playground)
        msg = """
please run
```julia
module playground end
```
to add the module to the Main scope, which will be used by @AI to call julia code
"""
        Markdown.parse(msg) |> display
    else
        # does not support stream mode
        # tmp = Brain.stream
        Brain.stream = false
        :( exe($(@ai($(expr)))))
        # Brain.stream = tmp; # recover the stream setting
        # res
    end
end


export @ai, @AI, exe, reset

end
