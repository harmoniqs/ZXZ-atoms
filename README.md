# ZXZ-atoms: Quantum Optimal Control for Rydberg Atom Arrays

**Engineering three-body ZXZ Hamiltonian dynamics on Rydberg atom chains using global pulse control**

This repository implements quantum optimal control for simulating non-native analog ZXZ Hamiltonian dynamics on Rydberg atom chains, demonstrating the research presented in ["Universal Dynamics with Globally Controlled Analog Quantum Simulators"](https://arxiv.org/abs/2508.19075).

## Overview

### The Problem: From Native Two-Body to Engineered Three-Body Interactions

**Target Hamiltonian (ZXZ Model - Cluster-Ising):**

$$
H_{\text{ZXZ}} = J_{\text{eff}} \sum_j Z_{j-1} X_j Z_{j+1}
$$

This three-body interacting Hamiltonian describes symmetry-protected topological (SPT) phases with edge modes, but cannot be directly implemented on Rydberg atom hardware.

**Native Rydberg Hamiltonian (Equation 19):**

$$
H(t)/\hbar = \frac{\Omega(t)}{2} \sum_i \sigma^x_i - \Delta(t) \sum_i n_i + \sum_{i<j} \frac{C_6}{r_{ij}^6} n_i n_j
$$

where:
- $\sigma^x_i$: Pauli-X operator coupling ground and Rydberg states (Rabi coupling)
- $n_i$: Number operator for Rydberg state occupation
- $\Omega(t)$: Time-dependent Rabi frequency driving transitions (global control)
- $\Delta(t)$: Time-dependent detuning of Rydberg level energy (global control)  
- $C_6/r_{ij}^6$: Van der Waals interactions between excited Rydberg atoms

**The Challenge:** Use only the native two-body interactions and global controls $\Omega(t)$, $\Delta(t)$ to engineer effective three-body ZXZ dynamics through optimal pulse sequences.

### Solution: Direct Quantum Optimal Control

This project uses **direct trajectory optimization** (inspired by robotics) to design smooth, experimentally feasible control pulses that:

1. **Synthesize effective three-body interactions** from native two-body Rydberg physics
2. **Operate outside the blockade regime** (atoms spaced at 8.9 μm > 8.37 μm blockade radius)
3. **Respect hardware constraints** (amplitude bounds, slew rates, finite resolution)
4. **Achieve high-fidelity dynamics** while minimizing decoherence

## Key Features

- **Piccolo.jl ecosystem**: Built on state-of-the-art quantum optimal control framework
- **Direct trajectory optimization**: Explores unphysical regions during optimization for better convergence
- **Hardware-aware design**: Incorporates realistic experimental constraints
- **Topological dynamics**: Demonstrates symmetry-protected edge modes in quantum many-body systems
- **Validation tools**: ODE-based forward simulation and fidelity analysis

## Repository Structure

```
├── ZXZ.ipynb              # Main demonstration notebook
├── src/                   # Source code modules
│   ├── ZXZAtoms.jl       # Main module interface
│   └── trajectories.jl   # Trajectory utilities
├── plotting.jl           # Visualization functions
├── Project.toml          # Julia dependencies
├── Manifest.toml         # Exact dependency versions
└── README.md             # This file
```

## Getting Started

### Prerequisites

- **Julia 1.8+** (recommended: latest stable version)
- **Git** for cloning the repository

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/harmoniqs/ZXZ-atoms.git
   cd ZXZ-atoms
   ```

2. **Start Julia and activate the project environment:**
   ```bash
   julia
   ```
   
   In the Julia REPL:
   ```julia
   using Pkg
   Pkg.activate(".")
   Pkg.instantiate()  # Install all dependencies
   ```

3. **Launch Jupyter notebook interface (optional):**
   ```julia
   using IJulia
   notebook()  # Opens Jupyter in browser
   ```

### Running the Main Notebook

**Option 1: VS Code (Recommended)**
- Open `ZXZ.ipynb` in VS Code with the Julia extension
- Select the project Julia environment
- Run cells sequentially

**Option 2: Jupyter Notebook**
- Launch with `jupyter notebook` in the project directory
- Open `ZXZ.ipynb` and run cells

**Option 3: Julia REPL**
```julia
# Navigate to the project directory in Julia
include("ZXZ.ipynb")  # If using NBInclude.jl
# Or copy-paste cell contents manually
```

### Key Dependencies

- **[Piccolo.jl](https://github.com/harmoniqs/Piccolo.jl)**: Quantum optimal control framework
- **[PiccoloQuantumObjects.jl](https://github.com/harmoniqs/PiccoloQuantumObjects.jl)**: Quantum state representations
- **[QuantumCollocation.jl](https://github.com/harmoniqs/QuantumCollocation.jl)**: Direct trajectory optimization
- **DataInterpolations.jl**: Control function interpolation
- **CairoMakie.jl**: Visualization

## Usage Examples

### Basic ZXZ Hamiltonian Optimization

```julia
using Piccolo
include("src/ZXZAtoms.jl")
using .ZXZAtoms

```julia
# Define target ZXZ Hamiltonian for 3 atoms
H_eff = operator_from_string("ZXZ")
U_goal = exp(-im * 0.8 * H_eff)  # Target evolution U = exp(-iθH_ZXZ)

# Setup Rydberg system (outside blockade regime)
sys = RydbergChainSystem(N=3, distance=8.9, ignore_Y_drive=true)

# Control bounds: [Ω_min, Δ_min] to [Ω_max, Δ_max]
a_bounds = ([0.0, -100.0], [15.7, 100.0])  # MHz

# Create initial trajectory with random controls
traj = unitary_rollout_trajectory(control_fn, G, T; 
    samples=26, control_bounds=a_bounds)

# Setup optimization problem
J = UnitaryInfidelityObjective(U_goal, :Ũ⃗, traj; Q=1e3)
J += QuadraticRegularizer(:u, traj, 1.0)

integrators = [TimeDependentBilinearIntegrator(Ĝ, traj, :Ũ⃗, :u, :t)]
prob = DirectTrajOptProblem(traj, J, integrators)

# Solve optimization
DirectTrajOpt.solve!(prob; max_iter=200)

# Check final fidelity
fidelity = unitary_fidelity(iso_vec_to_operator(prob.trajectory[end].Ũ⃗), U_goal)
println("Final fidelity: ", fidelity)
```

### Visualizing Results

```julia
# Plot control pulses
fig = plot_controls(prob.trajectory; 
    title="Optimized ZXZ Control Pulses")

# Validate with forward simulation
rollout_traj = unitary_rollout_trajectory(optimized_controls, G, T)
validation_fidelity = unitary_fidelity(iso_vec_to_operator(rollout_traj[end].Ũ⃗), U_goal)
```

## Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `N_atoms` | 3-5 | Number of atoms in chain |
| `distance` | 8.9 μm | Inter-atom spacing (outside blockade) |
| `Rabi_max` | 15.7 MHz | Maximum Rabi frequency |
| `Delta_max` | 100.0 MHz | Maximum detuning |
| `T` | 26 | Number of time samples |
| `dt` | 0.05 | Time step size |
| `θ` | 0.8 | Effective evolution parameter |

## Research Context

This implementation demonstrates:

1. **Universal quantum simulation**: Proving that analog quantum simulators with global control can realize universal quantum dynamics
2. **Direct optimal control**: New quantum control technique adapted from robotics for hardware-constrained optimization
3. **Three-body engineering**: First experimental realization of effective three-body interactions outside the Rydberg blockade regime
4. **Topological dynamics**: Demonstration of symmetry-protected topological edge modes in quantum many-body systems

## Citation

If you use this code in your research, please cite:

```bibtex
@article{hu2024universal,
  title={Universal Dynamics with Globally Controlled Analog Quantum Simulators},
  author={Hu, Hong-Ye and Gomez, Abigail McClain and Chen, Liyuan and Trowbridge, Aaron and Goldschmidt, Andy J. and Manchester, Zachary and Chong, Frederic T. and Jaffe, Arthur and Yelin, Susanne F.},
  journal={arXiv preprint arXiv:2508.19075},
  year={2024}
}
```

## Contributing

This is a research demonstration repository. For questions or collaborations, please reach out to the authors or open an issue.

## License

See [LICENSE](LICENSE) file for details.

## Links

- **Paper**: [Universal Dynamics with Globally Controlled Analog Quantum Simulators](https://arxiv.org/abs/2508.19075)
- **Piccolo.jl**: [Quantum Optimal Control Framework](https://github.com/harmoniqs/Piccolo.jl)
- **Harmoniqs**: [https://www.harmoniqs.co](https://www.harmoniqs.co/)
