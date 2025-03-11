module ModelComponents

"""
    AbstractModelComponent{FT<:AbstractFloat}

The base abstract type for all model components.
Parametrized by the floating-point type `FT` used for numerical calculations.
"""
abstract type AbstractModelComponent{FT<:AbstractFloat} end
const AMC = AbstractModelComponent
Base.eltype(::AbstractModelComponent{FT}) where {FT} = FT

"""
    AbstractIndividualModelComponent{FT<:AbstractFloat} <: AbstractModelComponent{FT}

Abstract type for individual model components that represent discrete entities
in the model. These components operate on single points or objects without
height-dependency.

Subtypes include parameters, state variables, forcing inputs, and auxiliary variables
for individual model elements.
"""
abstract type AbstractIndividualModelComponent{FT<:AbstractFloat} <: AMC{FT} end
const AIMC = AbstractIndividualModelComponent

"""
    AbstractHeightDependentModelComponent{FT<:AbstractFloat} <: AbstractIndividualModelComponent{FT}

Abstract type for model components that vary with height or depth in a vertical profile.
These components represent quantities that change along a vertical dimension and typically
contain values at different height/depth levels.
"""
abstract type AbstractHeightDependentModelComponent{FT<:AbstractFloat} <: AIMC{FT} end
const AHDMC = AbstractHeightDependentModelComponent

"""
    AbstractModelComponentSet{FT<:AbstractFloat} <: AbstractModelComponent{FT}

Abstract type for collections of related model components. Component sets group
multiple individual components of the same category together, providing organization
and encapsulation of related model elements.
"""
abstract type AbstractModelComponentSet{FT<:AbstractFloat} <: AMC{FT} end
const AMCS = AbstractModelComponentSet

# Auxiliary variables
"""
    AbstractAuxiliaryVariables{FT<:AbstractFloat} <: AbstractIndividualModelComponent{FT}

Abstract type for auxiliary variables that provide additional information or
intermediate calculations in the model. These variables are not part of the core
model state but are used to support model calculations.

See [`AbstractAuxiliaryVariableSet`](@ref) for an example of usage.
"""
abstract type AbstractAuxiliaryVariables{FT<:AbstractFloat} <: AIMC{FT} end

"""
    AbstractHeightDependentAuxiliaryVariables{FT<:AbstractFloat} <: AbstractHeightDependentModelComponent{FT}

Abstract type for height-dependent auxiliary variables. These variables provide
additional information or intermediate calculations that vary with height in the model.

See [`AbstractAuxiliaryVariableSet`](@ref) for an example of usage.
"""
abstract type AbstractHeightDependentAuxiliaryVariables{FT<:AbstractFloat} <: AHDMC{FT} end

"""
    AbstractAuxiliaryVariableSet{FT<:AbstractFloat} <: AbstractModelComponentSet{FT}

Abstract type for collections of auxiliary variables. Auxiliary variable groups
multiple auxiliary variables together, providing organization and encapsulation of
related model elements.

# Examples
```julia
Base.@kwdef struct HeightDependentHydrologicStateVariables{FT<:AbstractFloat} <:
                   AbstractHeightDependentModelComponent{FT}
    An::Matrix{FT} # Net CO₂ assimilation [μmol m⁻² s⁻¹]
    Dr::Matrix{FT} # Root distribution [-]
end

Base.@kwdef struct HydrologicAuxiliaryVariables{FT<:AbstractFloat} <:
                   AbstractAuxiliaryVariables{FT}
    high::HeightDependentHydrologicStateVariables{FT}
    low::HeightDependentHydrologicStateVariables{FT}

    alp_soil::Vector{FT} # Soil albedo [-]
    b_soil::Vector{FT} # Soil retention curve parameter [-]
end

Base.@kwdef struct BiogeochemistryAuxiliaryVariables{FT<:AbstractFloat} <:
                   AbstractAuxiliaryVariables{FT}
    BLit::Matrix{FT}
    NavlI::Matrix{FT}
end

Base.@kwdef struct AuxiliaryVariableSet{FT<:AbstractFloat} <:
                   AbstractAuxiliaryVariableSet{FT}
    hydrologic::HydrologicAuxiliaryVariables{FT}
    biogeochemistry::BiogeochemistryAuxiliaryVariables{FT}
end
```
"""
abstract type AbstractAuxiliaryVariableSet{FT<:AbstractFloat} <: AMCS{FT} end

# Forcing inputs
"""
    AbstractForcingInputs{FT<:AbstractFloat} <: AbstractIndividualModelComponent{FT}

Abstract type for forcing inputs that drive the model. Forcing inputs represent
external factors that influence the model behavior, such as meteorological or anthropogenic
data.

See [`AbstractForcingInputSet`](@ref) for an example of usage.
"""
abstract type AbstractForcingInputs{FT<:AbstractFloat} <: AIMC{FT} end

"""
    AbstractHeightDependentForcingInputs{FT<:AbstractFloat} <: AbstractHeightDependentModelComponent{FT}

Abstract type for height-dependent forcing inputs. These inputs vary with height
or depth in the model and control the behavior of the model at different levels.

See [`AbstractForcingInputSet`](@ref) for an example of usage.
"""
abstract type AbstractHeightDependentForcingInputs{FT<:AbstractFloat} <: AHDMC{FT} end

"""
    AbstractForcingInputSet{FT<:AbstractFloat} <: AbstractModelComponentSet{FT}

Abstract type for collections of forcing inputs. Forcing input sets group multiple
forcing inputs together, providing organization and encapsulation of related model elements.

# Examples
```julia
Base.@kwdef struct AnthropogenicInputs{FT<:AbstractFloat} <: AbstractForcingInputs{FT}
    Salt::Vector{FT} # Salt concentration
    IrD::Vector{FT} # Drip irrigation
end

Base.@kwdef struct MeteorologicalInputs{FT<:AbstractFloat} <: AbstractForcingInputs{FT}
    Pr::Vector{FT} # Precipitation
    Ta::Vector{FT} # Air temperature at reference height
    Ws::Vector{FT} # Wind speed at reference height
end

Base.@kwdef struct ForcingInputSet{FT<:AbstractFloat} <: AbstractForcingInputSet{FT}
    anthropogenic::AnthropogenicInputs{FT}
    meteorological::MeteorologicalInputs{FT}
end
```
"""
abstract type AbstractForcingInputSet{FT<:AbstractFloat} <: AMCS{FT} end

# Parameters
"""
    AbstractParameters{FT<:AbstractFloat} <: AbstractIndividualModelComponent{FT}

Abstract type for model parameters that define the model structure and behavior.
Parameters are fixed values or coefficients that control the model dynamics.

See [`AbstractParameterSet`](@ref) for an example of usage.
"""
abstract type AbstractParameters{FT<:AbstractFloat} <: AIMC{FT} end
"""
    AbstractHeightDependentParameters{FT<:AbstractFloat} <: AbstractHeightDependentModelComponent{FT}

Abstract type for height-dependent model parameters. These parameters vary with height
or depth in the model and control the behavior of the model at different levels.

See [`AbstractParameterSet`](@ref) for an example of usage.
"""
abstract type AbstractHeightDependentParameters{FT<:AbstractFloat} <: AHDMC{FT} end

"""
    AbstractParameterSet{FT<:AbstractFloat} <: AbstractModelComponentSet{FT}

Abstract type for collections of model parameters. Parameter sets group multiple
parameters together, providing organization and encapsulation of related model elements.

# Examples
```julia

Base.@kwdef struct SoilParameters{FT<:AbstractFloat} <: AbstractParameters{FT}
    Osat::FT # Saturation moisture 0 kPa
    Ohy::FT # Hygroscopic Moisture Evaporation cessation 10000 kPa
end

Base.@kwdef struct HeightDependentVegetationParameters{FT<:AbstractFloat} <:
                   AbstractHeightDependentParameters{FT}
    Knit::FT # Canopy nitrogen decay coefficient
    FI::FT # Intrinsic quantum efficiency
end

Base.@kwdef struct VegetationParameters{FT<:AbstractFloat} <: AbstractParameters{FT}
    high::HeightDependentParameters{FT}
    low::HeightDependentParameters{FT}

    KcI::FT # Interception drainage rate coefficient.
    Sllit::FT # Specific leaf area of litter

end

Base.@kwdef struct ParameterSet{FT<:AbstractFloat} <: AbstractParameterSet{FT}
    soil::SoilParameters{FT}
    vegetation::VegetationParameters{FT}
end
```
"""
abstract type AbstractParameterSet{FT<:AbstractFloat} <: AMCS{FT} end

# State variables
"""
    AbstractStateVariables{FT<:AbstractFloat} <: AbstractIndividualModelComponent{FT}

Abstract type for model state variables that represent the internal state of the model.
State variables are dynamic quantities that change over time and are used to track
the model evolution.

See [`AbstractStateVariableSet`](@ref) for an example of usage.
"""
abstract type AbstractStateVariables{FT<:AbstractFloat} <: AIMC{FT} end

"""
    AbstractHeightDependentStateVariables{FT<:AbstractFloat} <: AbstractHeightDependentModelComponent{FT}

Abstract type for height-dependent model state variables. These variables represent
the internal state of the model that varies with height or depth in the model.

See [`AbstractStateVariableSet`](@ref) for an example of usage.
"""
abstract type AbstractHeightDependentStateVariables{FT<:AbstractFloat} <: AHDMC{FT} end

"""
    AbstractStateVariableSet{FT<:AbstractFloat} <: AbstractModelComponentSet{FT}

Abstract type for collections of model state variables. State variable sets group
multiple state variables together, providing organization and encapsulation of related
model elements.

# Examples
```julia
Base.@kwdef struct HydrologicStateVariables{FT<:AbstractFloat} <:
                   AbstractStateVariables{FT}

    V::Matrix{FT} # Liquid water volume [mm]
    Tdp::Matrix{FT} # Soil temperature [°C]
end

Base.@kwdef struct HeightDependentVegetationStateVariables{FT<:AbstractFloat} <:
                   AbstractHeightDependentModelComponent{FT}
    AgeDL::Matrix{FT} # Average age of dead leaves
    B::Matrix{FT} # Biomass/carbon pools
end

Base.@kwdef struct VegetationStateVariables{FT<:AbstractFloat} <:
                   AbstractStateVariables{FT}
    high::HeightDependentVegetationStateVariables{FT}
    low::HeightDependentVegetationStateVariables{FT}
end

Base.@kwdef struct StateVariableSet{FT<:AbstractFloat} <:
                   AbstractStateVariableSet{FT}
    hydrologic::HydrologicStateVariables{FT}
    vegetation::VegetationStateVariables{FT}
end
```
"""
abstract type AbstractStateVariableSet{FT<:AbstractFloat} <: AMCS{FT} end

export AbstractModelComponent
export AbstractIndividualModelComponent, AbstractHeightDependentModelComponent
export AbstractModelComponentSet

export AbstractAuxiliaryVariables, AbstractHeightDependentAuxiliaryVariables
export AbstractAuxiliaryVariableSet
export AbstractForcingInputs, AbstractHeightDependentForcingInputs
export AbstractForcingInputSet
export AbstractParameters, AbstractHeightDependentParameters
export AbstractParameterSet
export AbstractStateVariables, AbstractHeightDependentStateVariables
export AbstractStateVariableSet

export AMC, AIMC, AHDMC, AMCS

end
