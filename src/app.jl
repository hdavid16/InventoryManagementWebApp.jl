function build_app(port=8050)
    app = dash(external_stylesheets = ["https://codepen.io/chriddyp/pen/bWLwgP.css"])
    app.layout = html_div() do 
        #Header
        dcc_markdown("
        #### Inventory Management Simulator
        *A discrete-time multi-product simulator for supply networks.*
        "),
        html_hr(),
        
        #Bill of Materials
        dcc_upload(
            id="upload_bill_of_materials",
            children=html_div([
                "1. Load bill of materials: "
                html_a("Select File")
            ]),
            multiple=false
        ),
        dcc_store(id="store_bill_of_materials",data=JSON.json(DataFrame())),
        html_div(id="show_bill_of_materials"),
        html_hr(),

        #Lead Times
        dcc_upload(
            id="upload_lead_times",
            children=html_div([
                "2. Load network lead times: "
                html_a("Select File")
            ]),
            multiple=false
        ),
        dcc_store(id="store_lead_times",data=JSON.json(DataFrame())),
        html_div(id="show_lead_times"),
        html_hr(),
        
        #Demand
        dcc_upload(
            id="upload_demand",
            children=html_div([
                "3. Load network demand: "
                html_a("Select File")
            ]),
            multiple=false
        ),
        dcc_store(id="store_demand",data=JSON.json(DataFrame())),
        html_div(id="show_demand"),
        html_hr(),
        
        #Inventory Policy
        dcc_upload(
            id="upload_policy",
            children=html_div([
                "4. Load inventory policy: "
                html_a("Select File")
            ]),
            multiple=false
        ),
        dcc_store(id="store_policy",data=JSON.json(DataFrame())),
        html_div(id="show_policy"),
        html_hr(),

        #Specify if tracking inventory position or echelon position
        html_div([
            "5. Select varible for inventory policy:",
            dcc_radioitems(
                id="policy_variable",
                options = [
                    (label="Inventory Position",value="inv_position"),
                    (label="Echelon Position",value="ech_position")
                ],
                value="inv_position",
            ),
        ]),
        html_hr(),

        #Specify if tracking inventory position or echelon position
        html_div([
            "6. Select policy type:",
            dcc_radioitems(
                id="policy_type",
                options = [
                    (label="(r, Q)",value="rQ"),
                    (label="(s, S)",value="sS")
                ],
                value="rQ",
            ),
        ]),
        html_hr(),

        #Specify if backlogging
        html_div([
            "7. Select operating mode:",
            dcc_radioitems(
                id="mode",
                options = [
                    (label="Backlog",value="backlog"),
                    (label="Lost Sales",value="lost_sales")
                ],
                value="backlog",
            ),
        ]),
        html_hr(),

        #Run Simulation
        html_div([
            "8. Number of periods to simulate: ",
            dcc_input(
                id="num_periods",
                type="number",
                min=0,
                value=0
            ),
            html_button("Build and Run Simulation Model", id="build_and_run", n_clicks=0),
        ]),
        dcc_confirmdialog(id = "sim_complete", message = ""),
        dcc_loading(html_div(id = "build_and_run_msg")),
        dcc_store(id = "store_inv_on_hand", data=JSON.json(DataFrame())),
        dcc_store(id = "store_inv_level", data=JSON.json(DataFrame())),
        dcc_store(id = "store_inv_position", data=JSON.json(DataFrame())),
        dcc_store(id = "store_ech_position", data=JSON.json(DataFrame())),
        dcc_store(id = "store_inv_pipeline", data=JSON.json(DataFrame())),
        dcc_store(id = "store_market_demand", data=JSON.json(DataFrame())),
        dcc_store(id = "store_replenishments", data=JSON.json(DataFrame())),

        #Download results
        html_div([
            html_button("Download Results", id="download", n_clicks=0),
            dcc_download(id="inv_onhand_result"),
            dcc_download(id="inv_level_result"),
            dcc_download(id="inv_position_result"),
            dcc_download(id="ech_position_result"),
            dcc_download(id="inv_pipeline_result"),
            dcc_download(id="market_demand_result"),
            dcc_download(id="replenishments_result")
        ])
    end

    build_callbacks(app)

    run_server(app, "0.0.0.0", port, debug=true)

    return nothing
end