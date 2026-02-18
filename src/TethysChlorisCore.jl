module TethysChlorisCore

using NCDatasets

include("ModelComponents.jl")
using .ModelComponents

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

include("check_extraneous_fields.jl")
export check_extraneous_fields

include("initialize.jl")
export initialize, validate_fields, preprocess_fields, initialize_field
export get_optional_fields, get_calculated_fields, get_required_fields
export get_dimensions

include("options.jl")
export AbstractOptions
export AbstractModelOptions, AbstractODEOptions, AbstractZeroFindingStrategies
export ZeroFindingStrategies, find_root

end
