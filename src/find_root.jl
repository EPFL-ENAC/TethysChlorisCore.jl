
"""
    find_root(
        f,
        x0,
        strategy::ZeroFindingStrategies{M};
        search_range = nothing,
    ) where {M}

Wrapper function to find a root of the function `f` using the specified `strategy`, given an
initial guess `x0`. Current implementations exists for both `Roots.jl` and
`SimpleNonlinearSolve.jl` strategies.

# Arguments
- `f`: Function for which to find a root
- `x0`: Initial guess for the root
- `strategy::ZeroFindingStrategies{M}`: Strategy for root finding
- `search_range`: Optional search range for bracketing methods (default: `nothing`)
"""
function find_root(f, x0, strategy::ZeroFindingStrategies{M}; kwargs...) where {M}
    throw(
        MethodError(
            "No method defined for find_root with strategy of type $(typeof(strategy))",
            (f, x0, strategy),
        ),
    )
end

function find_root(
    f, x0, strategy::ZeroFindingStrategies{M}; search_range=10.0
) where {M<:AbstractBracketingAlgorithm}
    (a, b) = find_bracket(f, x0, search_range)

    prob = IntervalNonlinearProblem((u, p) -> f(u), (a, b))
    sol = solve(prob, strategy.method; strategy.kwargs...)

    if !successful_retcode(sol)
        throw(ErrorException("Failed to converge: $(sol.retcode)"))
    end

    return sol.u, sol.resid
end

# Specialize the find_bracket function in the case where a bracket is already passed. In this
# case, we simply check whether the function does change size over the bracket
function find_bracket(f, x0::Tuple{Number,Number}, search_range=10.0)
    bracket = x0
    if f(x0[1]) * f(x0[2]) > 0
        bracket = find_bracket(f, 0.5*(x0[1] + x0[2]), search_range)
    end

    return bracket
end

function find_bracket(f, x0::Number, search_range=10.0)
    DT = search_range
    a = x0 - DT
    b = x0 + DT

    # Expand bracket if needed
    iter = 0
    max_bracket_expand = 10

    while f(a) * f(b) > 0 && iter < max_bracket_expand
        DT += 5.0
        a = x0 - DT
        b = x0 + DT
        iter += 1
    end

    if f(a) * f(b) > 0
        error("find_root: Unable to find suitable bracket for root finding around $x0.")
    end

    return (a, b)
end
