module InventoryManagementWebApp

using Dash
using CSV, DataFrames, Base64, JSON
using InventoryManagement, Distributions

export build_app

include("utils.jl")
include("callbacks.jl")
include("app.jl")

end # module