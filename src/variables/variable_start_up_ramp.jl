#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
"""
    start_up_unit_flow_indices(
        commodity=anything,
        node=anything,
        unit=anything,
        direction=anything,
        t=anything
    )

A list of `NamedTuple`s corresponding to indices of the `flow` variable where the keyword arguments act as filters
for each dimension.
"""
#TODO:
#TODO: improve generation
#only generate if max_start_up_ramp is defined and/or min_start_up_ramp
#what are the default values?
# rather model choise use ramps
### start_up_unit_flow
function start_up_unit_flow_indices(;unit=anything,
    node=anything,
    direction=anything,
    stochastic_scenario=anything,
    t=anything
)
    unit = expand_unit_group(unit)
    node = expand_node_group(node)
    unique([
        (unit=u, node=n, direction=d, stochastic_scenario=s, t=t)
        for (u,ng,d) in indices(max_startup_ramp)
        for unit in intersect(unit,u)
        for node in intersect(node,expand_node_group(ng))
        for direction in intersect(direction,d)
        for (u, n, d, s, t) in unit_flow_indices(
            unit=unit, node=node, direction=direction,
            stochastic_scenario=stochastic_scenario, t=t
        )])
end

"""
    add_variable_start_up_unit_flow!(m::Model)

Add `start_up_unit_flow` variables to model `m`.
"""
function add_variable_start_up_unit_flow!(m::Model)
    add_variable!(
        m,
        :start_up_unit_flow,
        start_up_unit_flow_indices;
        lb=x -> 0,
        fix_value=x -> fix_start_up_unit_flow(unit=x.unit, node=x.node, direction=x.direction, t=x.t, _strict=false)
    )
end
