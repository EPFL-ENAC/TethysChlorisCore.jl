module ModelComponents

abstract type AbstractModelComponent{FT<:AbstractFloat} end
const AMC = AbstractModelComponent
Base.eltype(::AbstractModelComponent{FT}) where {FT} = FT

abstract type AbstractIndividualModelComponent{FT<:AbstractFloat} <: AMC{FT} end
const AIMC = AbstractIndividualModelComponent

abstract type AbstractHeightDependentModelComponent{FT<:AbstractFloat} <: AIMC{FT} end
const AHDMC = AbstractHeightDependentModelComponent

abstract type AbstractModelComponentSet{FT<:AbstractFloat} <: AMC{FT} end
const AMCS = AbstractModelComponentSet

# Auxiliary variables
abstract type AbstractAuxiliaryVariables{FT<:AbstractFloat} <: AIMC{FT} end
abstract type AbstractHeightDependentAuxiliaryVariables{FT<:AbstractFloat} <: AHDMC{FT} end
abstract type AbstractAuxiliaryVariableSet{FT<:AbstractFloat} <: AMCS{FT} end

# Forcing inputs
abstract type AbstractForcingInputs{FT<:AbstractFloat} <: AIMC{FT} end
abstract type AbstractHeightDependentForcingInputs{FT<:AbstractFloat} <: AHDMC{FT} end
abstract type AbstractForcingInputSet{FT<:AbstractFloat} <: AMCS{FT} end

# Parameters
abstract type AbstractParameters{FT<:AbstractFloat} <: AIMC{FT} end
abstract type AbstractHeightDependentParameters{FT<:AbstractFloat} <: AHDMC{FT} end
abstract type AbstractParameterSet{FT<:AbstractFloat} <: AMCS{FT} end

# State variables
abstract type AbstractStateVariables{FT<:AbstractFloat} <: AIMC{FT} end
abstract type AbstractHeightDependentStateVariables{FT<:AbstractFloat} <: AHDMC{FT} end
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
