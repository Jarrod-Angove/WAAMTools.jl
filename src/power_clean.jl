# This module contains functions for importing data from the mess of files in raw_data

# Figuring out which files contain useful data and their filetype
# creating some filters
is_xlsx(myfile) = myfile[end-4:end] == ".xlsx"
not_joint(myfile) = !occursin("Joint", myfile) && !occursin("joint", myfile)
is_csv(myfile) = myfile[end-3:end] == ".csv"
is_fronius(myfile) = occursin("fronius", myfile)
is_weld(myfile) = occursin("weld", myfile)
has_date(myfile) = occursin("_202", myfile)

# There are three parsing methods required based on the above conditionals
filter1(fname) = is_xlsx(fname) && not_joint(fname)
filter2(fname) = is_csv(fname) && is_weld(fname) && not_joint(fname) && is_fronius(fname)
filter3(fname) = is_csv(fname) && !is_fronius(fname) && not_joint(fname)

struct xlsx
    name::AbstractString
    dir::AbstractString
end
struct csv_t1  
    name::AbstractString
    dir::AbstractString
end
struct csv_t2  
    name::AbstractString
    dir::AbstractString
end

# This is the main struct that holds the data
struct power_info
    voltage::Vector{Float64}
    current::Vector{Float64}
    time::Vector{Float64}
    file::String
end

# This converts the weird time stamps in some of the files
function to_time(x::AbstractString)
    secs = parse(Float64, x[18:end])
    mins = parse(Float64, x[15:16])
    t_secs = secs + mins*60
    return t_secs
end

# Function that generates the file objects based on the filters above
function file_typer(fname::AbstractString, dir::AbstractString)
    if filter1(fname)
        return xlsx(fname, dir)
    elseif filter2(fname) 
        return csv_t1(fname, dir) 
    elseif filter3(fname)
        return csv_t2(fname, dir)
    else 
        println("File $fname failed all filters")
    end
end

function file_typer(path::AbstractString)
    fname = splitpath(path)[end]
    dir = joinpath(splitpath(path)[1:end-1]...)
    if filter1(fname)
        return xlsx(fname, dir)
    elseif filter2(fname) 
        return csv_t1(fname, dir) 
    elseif filter3(fname)
        return csv_t2(fname, dir)
    else 
        println("File $fname failed all filters")
    end
end

# Using multiple dispatch to create 3 parsing functions based on file type
function parser(input::xlsx)
    path = joinpath(input.dir, input.name)
    xf = XLSX.readtable(path, 1, header = false, first_row = 2)
    # Convert the file to a julia matrix
    dmat = hcat(xf.data...)
    time = (dmat[:, 1] .- dmat[1, 1])./1e9
    return power_info(dmat[:,3], dmat[:, 2], time, input.name)
end

function parser(input::csv_t1)
    path = joinpath(input.dir, input.name)
    cv = CSV.File(path, header=false, skipto=2, footerskip=2)
    # time = cv.Column1 .- cv.Column1[1]
    if has_date(input.name)
        # This one has the weird time format
        times = to_time.(cv.Column1)
        time = times .- times[1]
        return power_info(cv.Column6, cv.Column7, time, input.name)
    else
        time = (cv.Column1 .- cv.Column1[1])./1e9
        return power_info(cv.Column8, cv.Column9, time, input.name)
    end
end

function parser(::Nothing)
    println("A file failed to parse")
end

function parser(input::csv_t2)
    path = joinpath(input.dir, input.name)
    cv = CSV.File(path, header=false, skipto=2, footerskip=2)
    time = (cv.Column1 .- cv.Column1[1])./1e9 # make time relative and convert to seconds
    return power_info(cv.Column3, cv.Column2, time, input.name)
end

"""
    importer(file, directory)

Import the power file CSV in `directory` into a `power_file` object, which has the fields:

* `voltage` = the voltage read from the CSV in [V]
* `current` = the current read from the CSV  in [A]
* `time` = the time, formated into seconds, from the CSV
* `file` = the file name input

For example, if you wanted to import the file `Plate18_power.csv`, located in the directory `home/user.../power_files/` , you would input the following in the REPL:

```julia-repl
julia> plate18_data = importer("Plate18_power.csv", "home/user.../power_files/")
```

Once you have a data object, you can acess the components with julia dot notation:

```julia-repl
julia> plate18_data.voltage
```
The above command will return a vector of the voltages stored in `plate18_data`.

Alternatively, you can input the complete file path as a single string to get the same results;

```julia-repl
julia> importer("home/use.../power_files/Plate18_power.csv")
```

Which will return the same data object.
"""
function importer(input::AbstractString, dir::AbstractString)
    file_typer(input, dir) |> parser
end

function importer(path::AbstractString)
    file_typer(path) |> parser
end

#### Export ####
# Function that calculates power from given power_dat struct (not including η or tts)
power_calc(pdat::power_info) = pdat.voltage .* pdat.current        # units are [W] end
# Exports only the relavent data to a given pathname
function export_cleaned(pdat::power_info, pathname::AbstractString)
    CSV.write(pathname,
    Tables.table(hcat(pdat.time, pdat.voltage, pdat.current, power_calc(pdat))),
    header=["time", "voltage", "current", "power"])
end


### Finding averages ### 

"""
    get_pdata(my_dir)

Import all of the files in the given directory. Before importing, name filters are checked to make sure it follows one of the conventions exported by the lab computer. It will return a vector of `power_info` structs.
"""
function get_pdata(my_dir::AbstractString)
examples = Vector()
rfiles = readdir(my_dir)
viable = vcat(filter(filter1, rfiles),
         filter(filter2, rfiles), filter(filter3, rfiles))
for item in viable
    try
        push!(examples, importer(item, my_dir));
    catch err
        println(err)
    end
end
return examples;
end

# Activation function to normalize the variance
sigmoid(x) = exp(x)/(1 + exp(x))
mean(x) = sum(x)/length(x)
σ(x) = (sqrt(sum((x .- mean(x)).^2) / (length(x) - 1)))

"""
    find_ranges(input_data::power_info)

Applies an algorithm based on the rolling variance to locate reasonable regions that can be used to estimate the mean power input. It takes a `power_info` object and returns a vector containing the selected ranges. 
"""
function find_ranges(inp::power_info)
    # Rolling variance window is based on the size of the data
    window = 10 + ceil(Int64, 0.024 * length(inp.time))
    win = convert(Float64, window)
    # Mean uses window size to avoid checking length on every itteration
    mean(x) = sum(x)/win
    # This is labeled variance but it's actual std; too lazy to fix
    var(x) = (sqrt(sum((x .- mean(x)).^2) / (win - 1)))

    powers = power_calc(inp)
    vars = Vector{Float64}()
    ts = inp.time[1:end-window]
    
    for i in 1:(length(powers) - window) 
        vr = var(powers[i:(i+window)])
        push!(vars, vr)
    end

    # Applying a sigmoid function to level things out
    vars = sigmoid.(vars./max(vars...))
    comb = hcat(ts, vars)

    # Filtering out low variance regions
    ans = vcat([comb[i, :] for i=1:length(vars)
        if comb[i, 2] > 1.02*min(vars[vars .!=0.0]...)]'...)

    jumps = Vector{Float64}()
    push!(jumps, ans[1, 1])

    # Seperating it into jumps if there is a time gap > 5 seconds
    for i in 2:(length(ans[:, 1])-1)
        if ((ans[i+1, 1] - ans[i, 1]) > 5) || ((ans[i, 1] - ans[i-1, 1]) > 5)
            push!(jumps, ans[i, 1])
        end
    end
    push!(jumps, ans[end, 1])

    # Snip off the first and last bits of data to only select stable regions
    function trim(rng::Vector{Float64})
        df = (rng[2] - rng[1])
        return [rng[1]+0.15*df, rng[2] - 0.05*df]
    end

    ranges = Vector{Vector{Float64}}()
    if length(jumps) == 2
        push!(ranges, trim(jumps[1:2]))
    elseif length(jumps) == 4
        push!(ranges, trim(jumps[1:2]))
        push!(ranges, trim(jumps[3:4]))
    else
        println("The length of jumps is $(length(jumps))")
    end

    return ranges
end

"""
    view_range(input_data::power_info)

Produce a plot showing the ranges that would be selected by the `find_ranges` function. This is a good way to check if the algorithm is selecting something reasonable.
"""
function view_range(inp::power_info)
    rngs = find_ranges(inp)
    plot(inp.time, power_calc(inp), legend=false)
    vspan!(rngs, alpha = 0.2)
    xlabel!("Time (s)")
    ylabel!("Power (W)")
end

function Plots.plot(inp::power_info)
    plot(inp.time, power_calc(inp), legend=false)
    xlabel!("Time (s)")
    ylabel!("Power (W)")
end

struct mean_data
    ranges::Vector{Vector{Float64}} # The selected range
    mean::Vector{Float64}           # The average power in the region
    nsamples::Int64                 # Number of samples in the file
    npoints::Vector{Int64}          # Number of points in the sample
    std::Vector{Float64}            # Standard deviation
end

struct sample_power
    name::AbstractString
    summary::mean_data
    hotcold::AbstractString
end

function split(inp::mean_data)
    if length(inp.ranges) == 2
        cold_data = mean_data([inp.ranges[1]], [inp.mean[1]],
            inp.nsamples, [inp.npoints[1]], [inp.std[1]])
        hot_data = mean_data([inp.ranges[2]], [inp.mean[2]],
            inp.nsamples, [inp.npoints[2]], [inp.std[2]])
        return(cold_data, hot_data)
    elseif length(inp.ranges) == 1
        println("This power info only contains one sample")
        return (cold_data)
    elseif length(inp.ranges) == 0
        println("Empty mean data")
    end
end

"""
    mean(input_data::power_info)

Find the mean(s) of the given `input_data`. This applies the `find_ranges` function and returns a tuple of `sample_power` objects. For example:

```julia-repl
julia> plate18_means = mean(plate18_data)
```

will produce the a tuple of objects, one for each region, called plate18_means. 

The sample_power objects have the fields `name`, `summary`, and `hotcold`, indicating the original file name, a summary of the calculated mean (including mean, standard deviation, and selected regions), and finally "h" for hot plate (for the second range) or "c" for cold plate.

If you wanted to see the mean of the output for the first region, you would use:

```julia-repl
julia> plate18_means[1].summary.mean
```

Similarly, if you wanted the standard deviation of the second region:

```julia-repl
julia> plate18_means[2].summary.std
```

It is important to note that this is a mean of the unadjusted power input in Watts, so no efficiency multiplier or torch travel speed has been applied. 
"""
function mean(inp::power_info)
    ranges = find_ranges(inp)
    means = Vector{Float64}()
    stds = Vector{Float64}()
    npoints = Vector{Float64}()
    nsamples = length(ranges)
    data = hcat(inp.time, power_calc(inp))
    for range in ranges
        dat = vcat([data[i, :] for i in 1:length(data[:, 1])
                if range[1] < data[i, 1] < range[2]]'...)
        push!(npoints, length(dat))
        push!(means, mean(dat[:, 2]))
        push!(stds, σ(dat[:, 2]))
    end
    out = split(mean_data(ranges, means, nsamples, npoints, stds))
    if length(out) == 2
        r1 = sample_power(inp.file, out[1], "c")
        r2 = sample_power(inp.file, out[2], "h")
        return (r1, r2)
    elseif length(out) == 1
        return sample_power(inp.file, out, "c")
    end
end



