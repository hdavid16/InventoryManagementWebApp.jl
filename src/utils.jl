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
    catch
    end
    
    return df
end

function show_table(df, filename, last_modified)
    if !isnothing(last_modified)
        last_modified = Libc.strftime(last_modified)
    end

    if isempty(df)
        filename = "An empty or invalid CSV file was loaded."
        last_modified = "Try again."
        color = "red"
    else
        color = "green"
    end
    return html_div([
        html_div("File Loaded: $filename", style = (color = color,)),
        html_div("Last Modified: $(last_modified)", style = (color = color,)),
        dash_datatable(
            data=[Dict(pairs(NamedTuple(eachrow(df)[j]))) for j in 1:nrow(df)],
            columns=[Dict("name" =>i, "id" => i) for i in names(df)],
            page_size=10
        ),
    ])
end

function build_network(lead_time_df)
    #initialize network
    node_names = union(lead_time_df.source,lead_time_df.destination)
    num_nodes = length(node_names)
    node_dict = Dict(n => i for (i,n) in enumerate(node_names))
    net = MetaDiGraph(num_nodes)
    set_prop!(net, :node_dictionary, node_dict)

    #add materials if provided
    materials = setdiff(names(lead_time_df), ["source", "destination"])
    set_prop!(net, :materials, materials)
    
    for row in eachrow(lead_time_df)
        src = node_dict[row.source]
        dst = node_dict[row.destination]
        if src != dst #store transportation lead times
            add_edge!(net, src, dst)
            set_prop!(net, src, dst, :lead_time, Dict(
                m => #if its a string, parse it; if the parsed value is a number then put make it a singleton array
                    row[m] isa String ? eval(Meta.parse(row[m])) : row[m] |>
                    i -> i isa Number ? [i] : i
                for m in materials if !isnothing(row[m])
            ))
        else #store production times
            set_prop!(net, src, :production_time, Dict(
                m => 
                    row[m] isa String ? eval(Meta.parse(row[m])) : row[m] 
                for m in materials if !isnothing(row[m])
            ))
        end
    end

    return net
end

function build_bom!(net, bom_df)
    isempty(bom_df) && return

    #extract list of materials 
    mats0 = get_prop(net, :materials)
    mats = union(bom_df.input,bom_df.output,mats0)

    #build bom
    bom = zeros(length(mats), length(mats))
    for row in eachrow(bom_df)
        src = row.input
        dst = row.output
        src_loc = findfirst(i -> i == src, mats)
        dst_loc = findfirst(i -> i == dst, mats)
        bom[src_loc,dst_loc] = -row.value
    end

    set_prop!(net, :materials, mats)
    set_prop!(net, :bill_of_materials, bom)
end

function build_demand!(net, demand_df)
    #parse values in third colun (distributions)
    transform!(demand_df,
        "demand_distribution" => #if its a string, parse it; if the parsed value is a number then put make it a singleton array
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i |>
                j -> j isa Number ? [j] : j
            )
            => :demand_distribution,
        "demand_frequency" => 
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :demand_frequency
    )

    #add demand distribution and frequency for each node
    node_dict = get_prop(net, :node_dictionary)
    demand_grp = groupby(demand_df, "node") #group by node
    for df in demand_grp
        node_name = df.node[1]
        node_id = node_dict[node_name]
        set_props!(net, node_id, Dict(
            :demand_distribution => Dict(
                df.material .=> df.demand_distribution
            ),
            :demand_frequency => Dict(
                df.material .=> df.demand_frequency
            )
        ))
    end
end

function run_policy!(net, policy_df, policy_variable, policy_type, num_periods, backlog)
    #parse initial inventory
    transform!(policy_df,
        "initial_inventory" => #initial inventory
            ByRow(
                i -> i isa String && lowercase(i) == "unlimited" ? Inf :
                     i isa String ? eval(Meta.parse(i)) : i
            )
            => :initial_inventory,
        "param1" => #parameter 1
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :param1,
        "param2" => #parameter 2
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :param2,
        "review_period" => #review period
            ByRow(
                i -> i isa String ? eval(Meta.parse(i)) : i
            )
            => :review_period
    )

    #update materials list
    mats = get_prop(net, :materials)
    union!(mats, policy_df.material)
    
    #set initial inventory levels
    node_dict = get_prop(net, :node_dictionary)
    policy_grp = groupby(policy_df, "node") #group by node
    for df in policy_grp
        node_name = df.node[1] #node id is the first column
        node_id = node_dict[node_name]
        set_prop!(net, node_id, :initial_inventory, Dict(
            df.material .=> df.initial_inventory
        ))
    end

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
        seed = rand(0:1000)
    )
    simulate_policy!(env, param1, param2; policy_variable, policy_type, review_period)

    return env
end
