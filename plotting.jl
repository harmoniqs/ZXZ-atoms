"""
plotting.jl

Visualization utilities for quantum control trajectories and Rydberg atom systems.
Provides functions to plot control pulses, populations, and optimization results.
"""

using CairoMakie

# Utility functions to ensure data is in plottable format
_to_vector(x::AbstractVector) = collect(x)
_to_vector(x::AbstractMatrix) = collect(x)
_extract_control(controls::AbstractMatrix, i::Int) = collect(controls[i, :])
_extract_times(times::AbstractVector) = collect(times)

"""
    plot_controls(traj::NamedTrajectory; kwargs...)
    plot_controls(times::AbstractVector, controls::AbstractMatrix; kwargs...)

Plot quantum control pulses with separate panels for each control signal.

For Rydberg systems with ignore_Y_drive=true:
- Control 1: Rabi frequency Ω(t) [MHz]
- Control 2: Detuning Δ(t) [MHz]

For full control (ignore_Y_drive=false):
- Control 1: Rabi_x(t) [MHz]  
- Control 2: Rabi_y(t) [MHz]
- Control 3: Detuning Δ(t) [MHz]

# Arguments
- `traj::NamedTrajectory`: Trajectory object containing control data
- `times::AbstractVector`: Time points (Vector, range, etc.)
- `controls::AbstractMatrix`: Control matrix (n_controls × n_time_points) - Matrix, sparse matrix, etc.

# Keyword Arguments
- `control_labels::Vector{String}`: Custom labels for controls (default: ["Ω(t)", "Δ(t)"] or ["Ω_x(t)", "Ω_y(t)", "Δ(t)"])
- `time_units::String`: Units for time axis (default: "μs")
- `control_units::String`: Units for control amplitude (default: "MHz")
- `figsize::Tuple`: Figure size (default: (800, 600))
- `linewidth::Real`: Line width for plots (default: 2.5)
- `colors::Vector`: Colors for each control (default: [:blue, :red, :green])
- `title::String`: Main figure title (default: "Quantum Control Pulses")
- `save_path::Union{String, Nothing}`: Path to save figure (default: nothing)

# Returns
- `Figure`: Makie figure object

# Examples
```julia
# Plot from trajectory object
fig = plot_controls(prob.trajectory)

# Plot from raw data with different array types
times = get_times(traj)  # Could be Vector, range, etc.
controls = traj.u       # Could be Matrix, SparseMatrix, etc.
fig = plot_controls(times, controls; title="Optimized ZXZ Control Pulses")

# Works with ranges and different matrix types
times_range = 0.0:0.05:1.3
sparse_controls = sparse([1.0 2.0 3.0; 4.0 5.0 6.0])
fig = plot_controls(times_range, sparse_controls)

# Customize labels and save
fig = plot_controls(traj; 
    control_labels=["Rabi Frequency", "Detuning"],
    title="Custom Control Pulses",
    save_path="control_pulses.png"
)
```
"""
function plot_controls(
    traj::NamedTrajectory;
    kwargs...
)
    times = get_times(traj)
    controls = traj.u
    return plot_controls(times, controls; kwargs...)
end

function plot_controls(
    times::AbstractVector{<:Real},
    controls::AbstractMatrix{<:Real};
    control_labels::Union{Vector{String}, Nothing} = nothing,
    time_units::String = "μs",
    control_units::String = "MHz", 
    figsize::Tuple = (800, 600),
    linewidth::Real = 2.5,
    colors::Vector = [:blue, :red, :green, :orange],
    title::String = "Quantum Control Pulses",
    save_path::Union{String, Nothing} = nothing
)
    n_controls, n_times = size(controls)
    
    # Default labels based on number of controls
    if isnothing(control_labels)
        if n_controls == 2
            control_labels = ["Ω(t) [Rabi]", "Δ(t) [Detuning]"]
        elseif n_controls == 3
            control_labels = ["Ω_x(t) [Rabi X]", "Ω_y(t) [Rabi Y]", "Δ(t) [Detuning]"]
        else
            control_labels = ["Control $i" for i in 1:n_controls]
        end
    end
    
    # Create figure with subplots
    fig = Figure(size=figsize)
    
    # Add main title
    Label(fig[0, :], title, fontsize=16, font="bold")
    
    # Create subplots for each control
    axes = []
    for i in 1:n_controls
        ax = Axis(fig[i, 1], 
            xlabel = i == n_controls ? "Time [$time_units]" : "",
            ylabel = "$(control_labels[i]) [$control_units]",
            xlabelsize = 12,
            ylabelsize = 12
        )
        
        # Plot control signal - ensure compatibility with different array types
        control_data = _extract_control(controls, i)
        time_data = _extract_times(times)
        
        lines!(ax, time_data, control_data, 
            color=colors[i], 
            linewidth=linewidth,
            label=control_labels[i]
        )
        
        # Add grid
        ax.xgridvisible = true
        ax.ygridvisible = true
        ax.xgridcolor = :gray
        ax.ygridcolor = :gray
        
        push!(axes, ax)
    end
    
    # Link x-axes for synchronized zooming
    for i in 2:n_controls
        linkxaxes!(axes[1], axes[i])
    end
    
    # Adjust layout
    rowgap!(fig.layout, 5)
    
    # Save if requested
    if !isnothing(save_path)
        save(save_path, fig)
        println("Figure saved to: $save_path")
    end
    
    return fig
end