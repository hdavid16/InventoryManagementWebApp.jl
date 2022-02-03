function parse_contents(contents, filename)
    df = DataFrame()

    isnothing(contents) && return df

    content_type, content_string = split(contents, ',')
    decoded = base64decode(content_string)

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
    
    return df
end

function show_table(df, filename, last_modified)
    if !isnothing(last_modified)
        last_modified = Libc.strftime(last_modified)
    end

    return html_div([
        html_div("File Name: $filename"),
        html_div("Last Modified: $(last_modified)"),
        dash_datatable(
            data=[Dict(pairs(NamedTuple(eachrow(df)[j]))) for j in 1:nrow(df)],
            columns=[Dict("name" =>i, "id" => i) for i in names(df)]
        ),
    ])
end

function build_network(lead_time_df)
    # columns: source, destination, material1, material2, ... (where the values under the materials are the lead times)
    #TODO: add checks to the lead_time_df input

    #initialize network
    node_names = union(lead_time_df[:,1],lead_time_df[:,2])
    num_nodes = length(node_names)
    node_dict = Dict(n => i for (i,n) in enumerate(node_names))
    set_prop!(net, :node_dictionary, node_dict)
    net = MetaDiGraph(num_nodes)

    #add materials if provided
    materials = names(lead_time_df)[3:end]
    set_prop!(net, :materials, materials)
    
    for row in eachrow(lead_time_df)
        src = node_dict[row[1]]
        dst = node_dict[row[2]]
        if src != dst #store transportation lead times
            add_edge!(net, src, dst)
            set_prop!(net, src, dst, :lead_time, Dict(
                m => #if its a string, parse it; if the parsed value is a number then put make it a singleton array
                    row[m] isa String ? eval(Meta.parse(row[m])) : row[m] |>
                    i -> i isa Number ? [i] : i
                for m in materials if !ismissing(row[m])
            ))
        else #store production times
            set_prop!(net, src, :production_time, Dict(
                m => 
                    row[m] isa String ? eval(Meta.parse(row[m])) : row[m] 
                for m in materials if !ismissing(row[m])
            ))
        end
    end

    return net
end

function build_bom!(net, bom_df)
    #TODO: check that materials in lead time df are all included in bom
    isempty(bom_df) && return

    #extract list of materials 
    mats = union(bom_df[:,1],bom_df[:,2])

    #build bom
    bom = zeros(length(mats), length(mats))
    for row in eachrow(bom_df)
        src = row[1]
        dst = row[2]
        src_loc = findfirst(i -> i == src, mats)
        dst_loc = findfirst(i -> i == dst, mats)
        bom[src_loc,dst_loc] = -row[3]
    end

    set_prop!(net, :materials, mats)
    set_prop!(net, :bill_of_materials, bom)
end

function build_demand!(net, demand_df)
    #parse values in third colun (distributions)
    transform!(demand_df,
        3 => #if its a string, parse it; if the parsed value is a number then put make it a singleton array
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i |>
                j -> j isa Number ? [j] : j
            )
            => :demand_distribution,
        4 => 
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :demand_frequency
    )

    #add demand distribution and frequency for each node
    node_dict = get_prop(net, :node_dictionary)
    demand_grp = groupby(demand, 1) #group by node
    for df in demand_grp
        node_name = df[1,1] #node id is in first column
        node_id = node_dict[node_name]
        set_props!(node_id, Dict(
            :demand_distribution => Dict(
                df[:,2] .=> df[:,:demand_distribution] #materials are in second column
            ),
            :demand_frequency => Dict(
                df[:,2] .=> df[:,:demand_frequency]
            )
        ))
    end
end

function run_policy!(net, policy_df, policy_variable, policy_type, num_periods, backlog)
    #parse initial inventory
    transform!(policy_df,
        3 => #initial inventory
            ByRow(
                i -> i isa String && lowercase(i) == "unlimited" ? Inf :
                     i isa String ? eval(Meta.parse(i)) : i
            )
            => :initial_inventory,
        4 => #parameter 1
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :param1,
        5 => #parameter 2
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :param2,
        6 => #review period
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :review_period
    )

    #build dictionaries for policy
    param1 = Dict((i[1],i[2]) => i[:param1] for i in eachrow(policy_df))
    param2 = Dict((i[1],i[2]) => i[:param2] for i in eachrow(policy_df))
    review_period = Dict((i[1],i[2]) => i[:review_period] for i in eachrow(policy_df))

    #create and run simulation
    env = SupplyChainEnv(
        net, 
        num_periods; 
        backlog,
        evaluate_profit = false,
        capacitated_inventory = false,
        seed
    )
    simulate_policy!(env, param1, param2; policy_variable, policy_type, review_period)
    #TODO: Do we want to include an MOQ?
end