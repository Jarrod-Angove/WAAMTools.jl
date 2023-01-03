# This files contains some structs that are used to sort data
abstract type exp_info end
abstract type trial_data <: exp_info end
abstract type sample_data <: trial_data end

struct material_props <: exp_info
    t_l::Float64        # Liquidus temperature
    t_s::Float64        # Solidus temperature
end

# This just holds the relavent directories for the data files
struct files <: exp_info
    power_dir::AbstractString
    pyro_dir::AbstractString
end

# Weld parameters for a single trial
struct weld_param <: trial_data
    tts::Float64        # Torch travel speed
    flow::Float64       # Gas flow rate
    wfs::Float64        # Wire feed speed
end

struct sample_collected <: sample_data
    plate::Int64                # Plate ID          
    param::weld_param           # Weld parameters
    hotcold::AbstractString     # "h" or "c" for hot or cold plate  
    power_file::AbstractString  # Name of the file containing power info
    pyro_file::AbstractString   # Name of the file containing pyrometer data
end
