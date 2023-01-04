module WAAMTools
using Plots, XLSX, CSV, Tables

include("structs.jl")
export exp_info, trial_data, sample_data, files, sample_collected

include("power_clean.jl")
export importer, mean, get_pdata, view_range, plot, find_ranges
export sample_power, mean_data

include("pyro_clean.jl")

end
