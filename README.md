# WAAMTools

This is a julia package that is intended to make the day-to-day data crunching at the university of Alberta WAAM lab a little easier. I haven't gotten around to porting over the pyrometer tools yet, so it's really just a fancy power data import tool for the time being.

My intention is to open up the code I have been using to others. By creating a package, the algorithms can be used in short scripts by others to automate new tasks.

# Getting Started

As this is a julia package, you will first need to install julia. The easiest way to do this is to follow the instructions at [the julia downloads page](https://julialang.org/downloads/).

Once julia is installed, you can download this package by opening the REPL (launching julia) and running the following command: 

```julia-repl
julia> import Pkg; Pkg.add("WAAMTools")
```

Once the package is installed, you can launch it:

```julia-repl
julia> using WAAMTools
```

You can then start using the functions provided by the package.

## Typical power import

As data for the WAAM system is collected in the form of CSV/xlsx files, it needs to be imported and cleaned up. This can be done with the importer command:

`importer(file, directory)`

Import the power file CSV in `directory` into a `power_file` object, which has the fields:

* `voltage` = the voltage read from the CSV in [V]
* `current` = the current read from the CSV in [A]
* `time` = the time, formatted into seconds, from the CSV
* `file` = the file name input

For example, if you wanted to import the file `Plate18_power.csv`, located in the directory `home/user.../power_files/`, you would input the following in the REPL:

```julia-repl
julia> plate18_data = importer("Plate18_power.csv", "home/user.../power_files/")
```

Once you have a data object, you can access the components with julia dot notation:

```julia-repl
julia> plate18_data.voltage
```
The above command will return a vector of the voltages stored in `plate18_data`.

Alternatively, you can input the complete file path as a single string to get the same results;

```julia-repl
julia> importer("home/use.../power_files/Plate18_power.csv")
```

Which will return the same data object.

Once you have a `power_info` object from this import, you can do a few things. The main purpose of this package at this time is splitting this power data into ranges for taking averages
