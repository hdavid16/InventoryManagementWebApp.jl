function build_app()
    app = dash(external_stylesheets = ["https://codepen.io/chriddyp/pen/bWLwgP.css"])
    app.layout = html_div() do 
        dcc_upload(
            id="upload_adjacency_matrix",
            children=html_div([
                "Drag and Drop or ",
                html_a("Select File")
            ]),
            multiple=false
        ),

        html_div(id="load_adjacency_matrix")
    end

    build_call_backs(app)

    run_server(app, "0.0.0.0", 8050, debug=true)

    return nothing
end