module AskAI
using HTTP, JSON3, Markdown
using ReplMaker: initrepl

include("brain.jl")

AI_API_KEY = "API key not set"
prompt_to_get_code = "if the answer contains code, only output the raw code in julia"

function __init__()
    global AI_API_KEY
    ######################################
    # check for the required AI_API_KEY  #
    ######################################
    if haskey(ENV, "AI_API_KEY")
        # println("AI_API_KEY is set to $(ENV["AI_API_KEY"])")
        setapi(ENV["AI_API_KEY"])
    else
        msg = """
API_KEY is needed. please set it as an environment variable:

```julia
ENV["AI_API_KEY"]="1234567890abcdef1234567890abcdef"
```

or set it through function `setapi()`
```julia
$(@__MODULE__).setapi("1234567890abcdef1234567890abcdef")

```
"""
        setapi("")
        display(Markdown.parse(msg))
    end

    isinteractive() || return
    initrepl(s -> Main.eval(Meta.parse("AskAI.@ai \"$s\""));
             prompt_text="ask ai> ",
             prompt_color=104,
             start_key='}',
             mode_name=:askai,
            )

end

"""
set the API_KEY
```julia
setapi("1234567890abcdef1234567890abcdef")
```
"""
function setapi(api::AbstractString)
    global AI_API_KEY = api
    global Brain = AIBrain(api=AI_API_KEY, prompt = prompt_to_get_code )
end


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
