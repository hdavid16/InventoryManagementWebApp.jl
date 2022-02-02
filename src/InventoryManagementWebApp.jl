module InventoryManagementWebApp

using Dash, DashHtmlComponents, DashCoreComponents, DashTable	
using DataFrames, Base64
using InventoryManagement

export build_app

include("utils.jl")
include("callbacks.jl")
include("app.jl")

end # module