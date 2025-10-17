# ZXZ-atoms Project Instructions

## Overview
This project implements optimal control for simulating non-native analog ZXZ Hamiltonian dynamics on Rydberg atom chains using the Piccolo.jl quantum control framework. This is a demonstration implementation for the research presented in ["Universal Dynamics with Globally Controlled Analog Quantum Simulators"](https://arxiv.org/abs/2508.19075).

## Architecture

### Core Components
- **`ZXZ.ipynb`**: Main notebook demonstrating the complete workflow from system setup to optimization
- **`helper_functions.jl`**: Custom trajectory utilities extending Piccolo functionality
- **Piccolo ecosystem**: Built on `Piccolo.jl`, `PiccoloQuantumObjects.jl`, and `QuantumCollocation.jl`

### Key Dependencies
- **Piccolo.jl**: Main quantum control framework providing `RydbergChainSystem`, trajectory optimization
- **DataInterpolations.jl**: For `LinearInterpolation` of control functions
- **DirectTrajOpt**: Optimization backend (commented import suggests conditional usage)
- **CairoMakie.jl**: Visualization via `plot_unitary_populations`

## Critical Patterns

### Quantum System Setup
```julia
# Target ZXZ Hamiltonian (cluster-Ising model): H_ZXZ = J_eff ∑_j Z_{j-1} X_j Z_{j+1}
H_eff = operator_from_string("ZXZ")  # 3 atoms
# Multi-atom chains: "ZXZI" + "IZXZ" (4 atoms), etc.

# Native Rydberg Hamiltonian (Equation 19 from paper):
# H(t)/ℏ = Ω(t)/2 ∑_l (σ^x_l) - Δ(t) ∑_l (σ^z_l) + ∑_{j<l} V_jl n_j n_l
# where V_jl = C6/|r_j - r_l|^6 (van der Waals interactions)
sys = RydbergChainSystem(N=N_atoms, distance=dist, ignore_Y_drive=true)
a_bounds = ([0.0, -Delta_max], [Rabi_max, Delta_max])  # Rabi, detuning
```

### Trajectory Construction Workflow
1. **Initial trajectory**: Use `unitary_rollout_trajectory()` from `HelperFunctions`
2. **Objective setup**: `UnitaryInfidelityObjective(U_goal, :Ũ⃗, traj)` + regularizers
3. **Integrator**: `TimeDependentBilinearIntegrator(Ĝ, traj, :Ũ⃗, :u, :t; linear_spline=true)`
4. **Optimization**: `DirectTrajOptProblem(traj, J, integrators)`

### Control Parameterization
- **Ignore Y-drive mode**: 2D controls `[Rabi, detuning]` with bounds `[0, -Δ_max]` to `[Ω_max, Δ_max]`
- **Full control**: 3D controls `[Rabi_x, Rabi_y, detuning]` with symmetric Rabi bounds
- **Interpolation**: `LinearInterpolation(u[j,:], times)(t)` for smooth control functions

### Isomorphism Convention
- Unitary operators stored as isomorphic vectors (`:Ũ⃗`) using `PiccoloQuantumObjects`
- Convert with `iso_vec_to_operator()` and `operator_to_iso_vec()`
- Fidelity measured via `unitary_fidelity(U_actual, U_goal)`

## Development Workflows

### Running Optimization
```julia
# Standard solver options for numerical stability
DirectTrajOpt.solve!(prob; 
    max_iter=200, 
    options=IpoptOptions(
        recalc_y="yes", 
        recalc_y_feas_tol=1e8,
        eval_hessian=false
    )
)
```

### Validation Pattern
```julia
# Always check fidelity before and after optimization
println(unitary_fidelity(iso_vec_to_operator(traj[end].Ũ⃗), U_goal))
# Rollout verification with optimized controls
rollout_traj = unitary_rollout_trajectory(control_fn, G, T; samples=T)
```

## Key Helper Functions
- **`unitary_rollout_trajectory()`**: ODE-based forward simulation with Tsit5 solver
- **`unitary_trajectory()`**: Constructs `NamedTrajectory` with proper bounds and goals
- **`add_derivatives!()`**: Adds derivative controls for smoothness (currently unused)

## Common Parameters
- **Time discretization**: `dt = 0.05`, `T = 26` samples
- **Physical limits**: `Rabi_max = 15.7`, `Delta_max = 100.0`, `dist = 8.9` (atom spacing)
- **Optimization weights**: `Q = 1e3` (fidelity), `R_u = 1.0` (control regularization)
- **Solver tolerances**: `abstol=1e-12`, `reltol=1e-12` for ODE integration