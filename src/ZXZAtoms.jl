"""
ZXZAtoms.jl

Main module for ZXZ Hamiltonian engineering on Rydberg atom chains.
Provides utilities for quantum optimal control and visualization.
"""

module ZXZAtoms

# Export main functionality
export unitary_rollout_trajectory
export unitary_trajectory  
export add_derivatives!
export plot_controls

# Include core modules
include("trajectories.jl")

# For plotting, we just include the file since it's self-contained
include("../plotting.jl")

end # module