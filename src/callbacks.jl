function parse_contents(contents, filename, date)
    content_type, content_string = split(contents, ',')
    decoded = base64decode(content_string)
    df = DataFrame()

    #read CSV file
    try
        if occursin("csv", filename)
            str = String(decoded)
            df =  CSV.read(IOBuffer(str), DataFrame)
        end
    catch e
        print(e)
        return html_div([
            "A valid CSV file needs to be provided. Try again."
        ])
    end

    return html_div([
        html_h5(filename),
        html_h6(Libc.strftime(date)),
  
        dash_datatable(
            data=[Dict(pairs(NamedTuple(eachrow(df)[j]))) for j in 1:nrow(df)],
            columns=[Dict("name" =>i, "id" => i) for i in names(df)]
        ),
  
        html_hr(),  # horizontal line
  
        # For debugging, display the raw contents provided by the web browser
        html_div("Raw Content"),
        html_pre(string(contents[1:200], "..."), style=Dict(
            "whiteSpace" => "pre-wrap",
            "wordBreak" => "break-all"
        ))
    ])
end

function load_adjacency_matrix(app)
    callback!(
        app,
        Output("load_adjacency_matrix", "children"),
        Input("upload_adjacency_matrix", "contents"),
        State("upload_adjacency_matrix", "filename"),
        State("upload_adjacency_matrix", "last_modified"),
    ) do contents, filename, last_modified
        if !(contents isa Nothing)
            children = [
                parse_contents(c...) for c in
                zip(contents, filename, last_modified)]
            return children
        end
    end
end

function build_call_backs(app)
    load_adjacency_matrix(app)
end