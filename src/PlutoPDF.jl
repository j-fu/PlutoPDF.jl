module PlutoPDF

import Pluto
using NodeJS
import JSON
import DefaultApplication

export html_to_pdf, pluto_to_pdf, pdf

# Stolen from https://discourse.julialang.org/t/collecting-all-output-from-shell-commands/15592
"Run a Cmd object, returning the stdout & stderr contents plus the exit code"
function execute(cmd::Cmd)
  out = Pipe()
  err = Pipe()

  process = run(pipeline(ignorestatus(cmd), stdout=out, stderr=err))
  close(out.in)
  close(err.in)

  (
    stdout = String(read(out)), 
    stderr = String(read(err)),  
    code = process.exitcode
  )
end

const default_options = (
    format ="A4",
    margin=(
        top="30mm",
        right="15mm",
        bottom="30mm",
        left="10mm",
    ),
    printBackground=true,
    displayHeaderFooter=false,
)

function html_to_pdf(html_path::AbstractString, output_path::Union{AbstractString,Nothing}=nothing; options=default_options, open=true, console_output=true)
    bin_script = normpath(joinpath(@__DIR__, "../node/bin.js"))

    output_path = something(output_path, Pluto.numbered_until_new(splitext(html_path)[1]; suffix=".pdf", create_file=false))

    @info "Generating pdf..."
    cmd = `$(nodejs_cmd()) $bin_script $(abspath(html_path)) $(abspath(output_path)) $(JSON.json(options))`
    if console_output
        run(cmd)
    else
        stdout, stderr, code = execute(cmd)
        if code != 0
            error(stderr)
        end
    end

    open && DefaultApplication.open(output_path)

    output_path
end


function pluto_to_pdf(notebook_path::AbstractString, output_path::Union{AbstractString,Nothing}=nothing; kwargs...)
    c = Pluto.Configuration.from_flat_kwargs(;
        disable_writing_notebook_files = true,
        lazy_workspace_creation = true,
    )
    s = Pluto.ServerSession(;options=c)
    @info "Running notebook..."
    nb = Pluto.SessionActions.open(s, notebook_path; run_async=false)
    html_contents = Pluto.generate_html(nb; binder_url_js="undefined", version="cd7c123")
    Pluto.SessionActions.shutdown(s, nb)

    filename = tempname() * ".html"
    write(filename, html_contents)

    output_path = something(output_path, Pluto.numbered_until_new(Pluto.without_pluto_file_extension(notebook_path); suffix=".pdf", create_file=false))

    html_to_pdf(filename, output_path; kwargs...)
end

@deprecate pdf(args...; kwargs...) pluto_to_pdf(args...; kwargs...)

end