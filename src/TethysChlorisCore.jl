module TethysChlorisCore

using NCDatasets
using SimpleNonlinearSolve: AbstractSimpleNonlinearSolveAlgorithm, SimpleNonlinearSolve
using SimpleNonlinearSolve: solve, IntervalNonlinearProblem
using BracketingNonlinearSolve: AbstractBracketingAlgorithm
using SciMLBase: successful_retcode
using StaticArraysCore: SVector, MVector

abstract type AbstractModel end

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
export AbstractModelOptions, AbstractODEOptions, ODEOptions

include("ZeroFindingStrategies.jl")
export AbstractZeroFindingStrategies, ZeroFindingStrategies
export SimpleBrentStrategy

include("find_root.jl")
export find_root

include("outputs.jl")
export AbstractStorageFrequency
export HourlyStorage, DailyStorage, StaticStorage, NoStorage
export hourly_storage, daily_storage, static_storage, no_storage
export storage_frequency, storage_size
export AbstractOutputsToSave, AllOutputs, NoOutputs
export decrease, outputs_to_save

include("output_writer.jl")
export VariableSpec, output_specs
export add_variable!, chunksizes, axis_names
export TimeEntry, TimeBuffers, store_buffer!, flush_buffers!
export StreamTask, make_task, store_task!, flush_tasks!, init_buffers!
export assign_slice!, assign_average_slice!
export cell_stats, domain_stats
end
