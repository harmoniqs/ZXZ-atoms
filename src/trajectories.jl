"""
trajectories.jl

Core trajectory utilities for quantum optimal control.
Functions for creating, rolling out, and manipulating quantum control trajectories.
"""

using OrdinaryDiffEqTsit5
using LinearAlgebra
using NamedTrajectories
using PiccoloQuantumObjects
import PiccoloQuantumObjects as PQO

function unitary_rollout_trajectory(
    u_fn::Function,
    G::Function,
    T::Float64;
    samples::Int=100,
    kwargs...
)
    ketdim = size(G(u_fn(0.0), 0.0), 1) ÷ 2

    Id = I(ketdim)

    Ũ⃗_init = PiccoloQuantumObjects.operator_to_iso_vec(1.0I(ketdim))

    f! = (dx, x, p, t) -> mul!(dx, kron(Id, G(u_fn(t), t)), x)

    prob = ODEProblem(f!, Ũ⃗_init, (0.0, T)) 

    times = collect(range(0.0, T, samples))

    Ũ⃗_traj = stack(solve(prob, Tsit5(); 
        abstol=1e-12, 
        reltol=1e-12, 
        saveat=times
    ).u)

    return unitary_trajectory(
       Ũ⃗_traj,
       stack([u_fn(t) for t ∈ times]),
       times;
       kwargs...
    )
end

function unitary_trajectory(
    Ũ⃗_traj::AbstractMatrix, 
    controls::AbstractMatrix,
    times::AbstractVector;
    U_goal=nothing,
    control_bounds=nothing,
    Δt_min=1e-3minimum(diff(times)),
    Δt_max=2maximum(diff(times))
)
    u_dim = size(controls, 1)

    ketdim = Int(sqrt(size(Ũ⃗_traj, 1) ÷ 2))

    Δt = diff(times)
    Δt = [Δt; Δt[end]]

    data = (
        Ũ⃗ = Ũ⃗_traj,
        u = controls,
        Δt = Δt,
        t = times,
    )

    initial = (;
        Ũ⃗ = Isomorphisms.operator_to_iso_vec(1.0I(ketdim)),
        u = zeros(u_dim)
    ) 

    final = (;
        u = zeros(u_dim),
    )

    goal = (;)

    if !isnothing(U_goal)
        goal = merge(goal, (;
            Ũ⃗ = Isomorphisms.operator_to_iso_vec(U_goal),
        ))
    end

    bounds = (;
        Ũ⃗ = (-ones(size(Ũ⃗_traj, 1)), ones(size(Ũ⃗_traj, 1))),
        Δt = (Δt_min, Δt_max),
    )

    if !isnothing(control_bounds)
        bounds = merge(bounds, (;u = control_bounds,))
    end

    return NamedTrajectory(
        data,
        controls=(:u),
        timestep=:Δt,
        bounds=bounds,
        initial=initial,
        final=final,
        goal=goal,
    )
end

function add_derivatives!(
    traj::NamedTrajectory, 
    name::Symbol; 
    order=1,
    rand_data=true
)
    traj.state_names = (traj.state_names..., name)
    names = [name]
    for i = 1:order
        derivative_name = Symbol("d"^i * string(name))
        if rand_data
            derivative_data = 2rand(traj.dims[name], traj.T) .- 1
        else
            derivative_data = derivative(traj[names[end]], get_timesteps(traj))
        end
        add_component!(traj, derivative_name, derivative_data; type=i==order ? :control : :state)
        push!(names, derivative_name)
    end
    traj.control_names = filter(x -> x != name, traj.control_names)
    traj.control_names = filter(x -> x != traj.timestep, traj.control_names)
    traj.control_names = (traj.control_names..., traj.timestep)
    traj.names = filter(x -> x != traj.timestep, traj.names)
    traj.names = (traj.names..., traj.timestep)
    traj.components = merge(traj.components, (;controls = vcat([collect(traj.components[c]) for c ∈ traj.control_names]...,)))
    return nothing
end