#############################################################################
# Copyright (C) 2017 - 2023  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
"""
    add_variable!(m::Model, name::Symbol, indices::Function; <keyword arguments>)

Add a variable to `m`, with given `name` and indices given by interating over `indices()`.

# Arguments

  - `lb::Union{Function,Nothing}=nothing`: given an index, return the lower bound.
  - `ub::Union{Function,Nothing}=nothing`: given an index, return the upper bound.
  - `bin::Union{Function,Nothing}=nothing`: given an index, return whether or not the variable should be binary
  - `int::Union{Function,Nothing}=nothing`: given an index, return whether or not the variable should be integer
  - `fix_value::Union{Function,Nothing}=nothing`: given an index, return a fix value for the variable or nothing
  - `non_anticipativity_time::Union{Function,Nothing}=nothing`: given an index, return the non-anticipatity time or nothing
  - `non_anticipativity_margin::Union{Function,Nothing}=nothing`: given an index, return the non-anticipatity margin or nothing
"""
function add_variable!(
    m::Model,
    name::Symbol,
    indices::Function;
    bin::Union{Function,Nothing}=nothing,
    int::Union{Function,Nothing}=nothing,
    lb::Union{Constant,Parameter,Nothing}=nothing,
    ub::Union{Constant,Parameter,Nothing}=nothing,
    initial_value::Union{Parameter,Nothing}=nothing,
    fix_value::Union{Parameter,Nothing}=nothing,
    internal_fix_value::Union{Parameter,Nothing}=nothing,
    replacement_value::Union{Function,Nothing}=nothing,
    non_anticipativity_time::Union{Parameter,Nothing}=nothing,
    non_anticipativity_margin::Union{Parameter,Nothing}=nothing,
)
    m.ext[:spineopt].variables_definition[name] = Dict{Symbol,Union{Function,Parameter,Nothing}}(
        :indices => indices,
        :bin => bin,
        :int => int,
        :non_anticipativity_time => non_anticipativity_time,
        :non_anticipativity_margin => non_anticipativity_margin
    )
    var = m.ext[:spineopt].variables[name] = Dict(
        ind => _variable(
            m,
            name,
            ind,
            bin,
            int,
            lb,
            ub,
            fix_value,
            internal_fix_value,
            replacement_value
        )
        for ind in indices(m; t=vcat(history_time_slice(m), time_slice(m)))
    )
    # Apply initial value, but make sure it updates itself by using a TimeSeries Call
    if initial_value !== nothing
        last_history_t = last(history_time_slice(m))
        t = model_start(model=m.ext[:spineopt].instance)
        dur_unit = _model_duration_unit(m.ext[:spineopt].instance)
        for (ind, v) in var
            overlaps(ind.t, last_history_t) || continue
            val = initial_value(; ind..., _strict=false)
            val === nothing && continue
            initial_value_ts = parameter_value(TimeSeries([t - dur_unit(1), t], [val, NaN]))
            fix(v, Call(initial_value_ts, (t=ind.t,)))
        end
    end
    merge!(var, _representative_periods_mapping(m, var, indices))
end

"""
    _representative_index(ind)

The representative index corresponding to the given one.
"""
function _representative_index(m, ind, indices)
    representative_t = representative_time_slice(m, ind.t)
    representative_inds = indices(m; ind..., t=representative_t)
    first(representative_inds)
end

"""
    _representative_periods_mapping(v::Dict{VariableRef}, indices::Function)

A `Dict` mapping non representative indices to the variable for the representative index.
"""
function _representative_periods_mapping(m::Model, var::Dict, indices::Function)
    # By default, `indices` skips represented time slices for operational variables other than node_state,
    # as well as for investment variables. This is done by setting the default value of the `temporal_block` argument
    # to `temporal_block(representative_periods_mapping=nothing)` - so any blocks that define a mapping are ignored.
    # To include represented time slices, we need to specify `temporal_block=anything`.
    # Note that for node_state and investment variables, `represented_indices`, below, will be empty.
    representative_indices = indices(m)
    all_indices = indices(m, temporal_block=anything)
    represented_indices = setdiff(all_indices, representative_indices)
    Dict(ind => var[_representative_index(m, ind, indices)] for ind in represented_indices)
end

_base_name(name, ind) = string(name, "[", join(ind, ", "), "]")

function _variable(m, name, ind, bin, int, lb, ub, fix_value, internal_fix_value, replacement_value)
    if replacement_value !== nothing
        ind = (analysis_time=_analysis_time(m), ind...)
        value = replacement_value(ind)
        if value !== nothing
            return value
        end
    end
    var = @variable(m, base_name = _base_name(name, ind))
    ind = (analysis_time=_analysis_time(m), ind...)
    bin !== nothing && bin(ind) && set_binary(var)
    int !== nothing && int(ind) && set_integer(var)
    lb === nothing || set_lower_bound(var, lb[(; ind..., _strict=false)])
    ub === nothing || set_upper_bound(var, ub[(; ind..., _strict=false)])
    fix_value === nothing || fix(var, fix_value[(; ind..., _strict=false)])
    internal_fix_value === nothing || fix(var, internal_fix_value[(; ind..., _strict=false)])
    var
end
