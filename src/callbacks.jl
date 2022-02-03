function show_lead_times(app, prop)
    callback!(
        app,
        Output("show_$prop", "children"),
        Output("store_$prop", "data"),
        Input("upload_$prop", "contents"),
        State("upload_$prop", "filename"),
        State("upload_$prop", "last_modified"),
    ) do contents, filename, last_modified
        df = parse_contents(contents, filename)
        df_show = show_table(df, filename, last_modified)
        df_json = JSON.json(df) 
        return df_show, df_json
    end
end

function run_simulation(app)
    callback!(
        app,
        Output("sim_complete", "displayed"),
        Output("sim_complete", "message"),
        Output("build_and_run_msg", "children"),
        Output("store_inv_on_hand", "data"),
        Output("store_inv_level", "data"),
        Output("store_inv_position", "data"),
        Output("store_ech_position", "data"),
        Output("store_inv_pipeline", "data"),
        Output("store_market_demand", "data"),
        Output("store_replenishments", "data"),
        Input("build_and_run", "n_clicks"),
        State("store_bill_of_materials", "data"),
        State("store_lead_times", "data"),
        State("store_demand", "data"),
        State("store_policy", "data"),
        State("policy_variable","value"),
        State("policy_type","value"),
        State("mode","value"),
        State("num_periods","value"),
        prevent_initial_call = true
    ) do n_clicks, bom_json, lt_json, demand_json, policy_json, policy_variable, policy_type, op_mode, num_periods
        #initialize outputs
        msg = html_div("")
        msg_txt = ""
        display = false
        inv_on_hand = DataFrame()
        inv_level = DataFrame()
        inv_position = DataFrame()
        ech_position = DataFrame()
        inv_pipeline = DataFrame()
        demand = DataFrame()
        replenishments = DataFrame()

        #trigger function call 
        if n_clicks > 0 && num_periods > 0
            #parse inputs
            bom_df = DataFrame(JSON.parse(bom_json))
            lt_df = DataFrame(JSON.parse(lt_json))
            demand_df = DataFrame(JSON.parse(demand_json))
            policy_df = DataFrame(JSON.parse(policy_json))
            backlog = op_mode == "backlog"
            policy_variable = Symbol(policy_variable)
            policy_type = Symbol(policy_type)
            
            #buiold and run model
            net = build_network(lt_df)
            build_bom!(net, bom_df)
            build_demand!(net, demand_df)
            run_policy!(net, policy_df, policy_variable, policy_type, num_periods, backlog)

            #competion message
            msg_txt = "Simulation Complete!"
            msg = html_div(msg_txt, style = (color = "green",))
            display = true

            #prepare results
            node_dict = get_prop(net, :node_dictionary)
            node_names = Dict(val => key for (key,val) in node_dict)
            inv_on_hand = env.inv_on_hand
            inv_level = env.inv_level
            inv_position = env.inv_position
            ech_position = env.ech_position
            demand = env.demand
            inv_pipeline = env.inv_pipeline
            replenishments = env.replenishments
            for df in [inv_on_hand, inv_level, inv_position, ech_position, demand]
                transform!(df,
                    :node => ByRow(i -> node_names[i]) => :node
                )
            end
            for df in [inv_pipeline, replenishments]
                transform!(df,
                    :arc => ByRow(i -> (node_names[i[1]], node_names[i[2]])) => :arc
                )
            end
        end

        return display, msg_txt, msg, 
            JSON.json(inv_on_hand), JSON.json(inv_level), 
            JSON.json(inv_position), JSON.json(ech_position), 
            JSON.json(inv_pipeline), JSON.json(demand), 
            JSON.json(replenishments)
    end
end

function download_results(app)
    callback!(
        app,
        Output("inv_onhand_result", "data"),
        Output("inv_level_result", "data"),
        Output("inv_position_result", "data"),
        Output("ech_position_result", "data"),
        Output("inv_pipeline_result", "data"),
        Output("market_demand_result", "data"),
        Output("replenishments_result", "data"),
        Input("download", "n_clicks"),
        State("store_inv_on_hand", "data"),
        State("store_inv_level", "data"),
        State("store_inv_position", "data"),
        State("store_ech_position", "data"),
        State("store_inv_pipeline", "data"),
        State("store_market_demand", "data"),
        State("store_replenishments", "data"),
        prevent_initial_call = true
    ) do n_clicks, inv_onhand_json, inv_level_json, inv_position_json, ech_position_json, inv_pipeline_json, market_demand_json, replenishments_json
        #parse results data
        inv_onhand = DataFrame(JSON.parse(inv_onhand_json))
        inv_level = DataFrame(JSON.parse(inv_level_json))
        inv_position = DataFrame(JSON.parse(inv_position_json))
        ech_position = DataFrame(JSON.parse(ech_position_json))
        inv_pipeline = DataFrame(JSON.parse(inv_pipeline_json))
        market_demand = DataFrame(JSON.parse(market_demand_json))
        replenishments = DataFrame(JSON.parse(replenishments_json))
        
        return dcc_send_string(CSV.write, inv_onhand, "inv_onhand.csv"),
            dcc_send_string(CSV.write, inv_level, "inv_level.csv"),
            dcc_send_string(CSV.write, inv_position, "inv_position.csv"),
            dcc_send_string(CSV.write, ech_position, "ech_position.csv"),
            dcc_send_string(CSV.write, inv_pipeline, "inv_pipeline.csv"),
            dcc_send_string(CSV.write, market_demand, "market_demand.csv"),
            dcc_send_string(CSV.write, replenishments, "replenishments.csv")
    end
end

function build_callbacks(app)
    show_lead_times(app, "bill_of_materials")
    show_lead_times(app, "lead_times")
    show_lead_times(app, "demand")
    show_lead_times(app, "policy")
    run_simulation(app)
    download_results(app)
end