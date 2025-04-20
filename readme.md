
<a href="https://aibiolab.github.io/AskAI" target="_blank" rel="noopener noreferrer">
    <img alt="Static Badge" src="https://img.shields.io/badge/docs-0.1.2-green">
</a>

AskAI.jl, as its name suggests, is a straightforward tool for querying Large Language Models. 
Currently supporting ollama and Google's Gemini model API. it's designed to be simple and direct: send prompts and questions to AI provider, and optionally execute the included code within a sandboxed "playground" to avoid affecting the main scope.

The main macro, `@ai`, retrieves results from a large language model, while `@AI` executes the code within the "playground" scope and displays the output(or any errors.)

a REPL mode was also support. Press `}` to enter and backspace to exit

## Overview
![AskAI](./overview.png)

## Screenshot
![screenshot](./docs/src/result3.png)
