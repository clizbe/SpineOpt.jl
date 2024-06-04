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
    unit_flow_indices(
        unit=anything,
        node=anything,
        direction=anything,
        s=anything
        t=anything
    )

A list of `NamedTuple`s corresponding to indices of the `unit_flow` variable where the keyword arguments act as filters
for each dimension.
"""
function unit_flow_indices(
    m::Model;
    unit=anything,
    node=anything,
    direction=anything,
    stochastic_scenario=anything,
    t=anything,
    temporal_block=temporal_block(representative_periods_mapping=nothing),
)
    unit = members(unit)
    node = members(node)
    (
        (unit=u, node=n, direction=d, stochastic_scenario=s, t=t)
        for (u, n, d) in unit__node__direction(unit=unit, node=node, direction=direction, _compact=false)
        for (n, s, t) in node_stochastic_time_indices(
            m; node=n, stochastic_scenario=stochastic_scenario, temporal_block=temporal_block, t=t
        )
    )
end

function unit_flow_ub(m; unit, node, direction, kwargs...)
    any(
        unit_flow_capacity(; unit=unit, node=ng, direction=direction, kwargs..., _strict=false) !== nothing
        for ng in groups(node)
    ) && return nothing
    unit_flow_capacity(m; unit=unit, node=node, direction=direction, kwargs..., _default=NaN) * (
        + number_of_units(m; unit=unit, kwargs..., _default=1)
        + candidate_units(m; unit=unit, kwargs..., _default=0)
    )
end

function _simple_fix_ratio_unit_flow_and_units_on_coeff_indices(m, d1, d2, fix_flow_ratio)
    (
        (u, n1, d1, n2, d2, s, t, _simple_fix_ratio_unit_flow_and_units_on_coeff(m, u, n1, n2, s, t, fix_flow_ratio)...)
        for (u, n1, n2) in indices(fix_flow_ratio)
        if _has_simple_fix_ratio_unit_flow(n1, n2, fix_flow_ratio)
        for (_n, s, t) in node_stochastic_time_indices(m; node=n1)
    )
end

function _simple_fix_ratio_unit_flow_and_units_on_coeff(m, u, n1, n2, s, t, fix_flow_ratio)
    fix_units_on_coeff = Dict(
        fix_ratio_out_in_unit_flow => fix_units_on_coefficient_out_in,
        fix_ratio_in_out_unit_flow => fix_units_on_coefficient_in_out,
    )[fix_flow_ratio]
    (
        fix_flow_ratio(m; unit=u, node1=n1, node2=n2, stochastic_scenario=s, t=t, _strict=false),
        fix_units_on_coeff(m; unit=u, node1=n1, node2=n2, stochastic_scenario=s, t=t, _default=0),
    )
end

function _has_simple_fix_ratio_unit_flow(n1, n2, fix_flow_ratio)
    _similar(n1, n2) && fix_flow_ratio in (fix_ratio_out_in_unit_flow, fix_ratio_in_out_unit_flow)
end

"""
    add_variable_unit_flow!(m::Model)

Add `unit_flow` variables to model `m`.
"""
function add_variable_unit_flow!(m::Model)
    d_to, d_from = direction(:to_node), direction(:from_node)
    replacement_expressions = Dict(
        (unit=u, node=n1, direction=d1, stochastic_scenario=s, t=t) => Dict(
            :unit_flow => ((unit=u, node=n2, direction=d2, stochastic_scenario=s, t=t), fix_flow_ratio),
            :units_on => ((unit=u, stochastic_scenario=s, t=t), fix_units_on_coeff),
        )
        for (u, n1, d1, n2, d2, s, t, fix_flow_ratio, fix_units_on_coeff) in Iterators.flatten(
            (
                _simple_fix_ratio_unit_flow_and_units_on_coeff_indices(m, d_to, d_from, fix_ratio_out_in_unit_flow),
                _simple_fix_ratio_unit_flow_and_units_on_coeff_indices(m, d_from, d_to, fix_ratio_in_out_unit_flow),
            )
        )
        if fix_flow_ratio !== nothing
    )
    add_variable!(
        m,
        :unit_flow,
        unit_flow_indices;
        lb=min_unit_flow,
        ub=unit_flow_ub,
        fix_value=fix_unit_flow,
        initial_value=initial_unit_flow,
        non_anticipativity_time=unit_flow_non_anticipativity_time,
        non_anticipativity_margin=unit_flow_non_anticipativity_margin,
        replacement_expressions=replacement_expressions,
    )
end
