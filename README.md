# InventoryManagementWebApp

This is a quick and simple interface to run [InventoryManagement.jl](https://github.com/hdavid16/InventoryManagement.jl) using [Dash](https://dash.plotly.com/julia). The webapp is also hosted on [Heroku](https://supply-chain-sim.herokuapp.com/).

## Inputs

The interface will request loading 4 CSV files as inputs to build the simulation environment (*Note*: all names are case sensitive and **must be strings**, not numbers. If you have a numerical identifier for a name, preceed it by a string, i.e., `100 -> m100`):
- Bill of Materials: must have the following columns:
  - `input`: material input name 
  - `output`: material produced name 
  - `value`: amount of input consumed to produce 1 unit of output
- Lead Times: must have the following columns 
  - `source`: source node name 
  - `destination`: destination node name 
  - materials: one column should be added for each material in the network. An integer number of periods can be specified as the `lead time` for that `arc` (`source -> destination`). Alternately, a valid univariate distribution from [Distributions.jl](https://juliastats.org/Distributions.jl/stable/univariate/) can be specified **inside quotes ("")**. *Note*: Distributions that can take negative values (i.e., `Normal` distribution) will be truncated at `0`. This will shift the actual mean of the distribution.
- Demand: must have the following columns 
  - `node`: node name 
  - `material`: material name 
  - `demand_distribution`: An integer number of units demanded for that `material` at that `node`. Alternately, a valid univariate distribution from [Distributions.jl](https://juliastats.org/Distributions.jl/stable/univariate/) can be specified **inside quotes ("")**. *Note*: Distributions that can take negative values (i.e., `Normal` distribution) will be truncated at `0`. This will shift the actual mean of the distribution.
  - `demand_frequency`: An integer number of periods that will transpire (on average) between demands for that `material` at that `node`.
- Policy: must have the following columns
  - `node`: node name
  - `material`: material name
  - `initial_inventory`: starting inventory quantity for that `material` at that `node`. If unlimited demand, use `unlimited`. 
  - `param1`: reorder point for the inventory policy (`r` for `(r, Q)` or `s` for `(s, S)`)
  - `param2`: second parameter for the inventory policy (`Q` for `(r, Q)` or `S` for `(s, S)`)
  - `review_period`: integer number of periods between each inventory review

*Note*: Sample input files are included in `./sample_inputs/`.

## Outputs

The simulation can then be run for the number of periods specified on the webapp interface. Once the simulation completes, the timeseries results can be downloaded as CSVs:
- Inventory Levels
- Inventory Positions
- Echelon Positions
- Onhand Inventory
- Pipeline Inventory
- Replenishment Orders
- Market Demand

## Tips
- For best performance with the Heroku app, use a standard web browser that is up to date. 
- When downloading result files, your browser will prompt you to allow multiple file downloads.
