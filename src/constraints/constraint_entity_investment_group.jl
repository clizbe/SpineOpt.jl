#############################################################################
# Copyright (C) 2017 - 2023  Spine Project
#
# This file is part of SpineOpt.
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
    add_constraint_entity_investment_group!(m::Model)

Force investment variables for first entity in the group and all other entities in the group to be equal.
"""
function add_constraint_entity_investment_group!(m::Model)
    @fetch (
        units_invested_available, connections_invested_available, storages_invested_available
    ) = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:entity_investment_group] = Dict(
        (investment_group=ig, entity1=e, entity2=other_e, stochastic_scenario=s, t=t) => @constraint(
            m,
            + expr_sum(
                units_invested_available[e, s, t]
                for (e, s, t) in units_invested_available_indices(m; unit=e, stochastic_scenario=s, t=t);
                init=0
            )
            + expr_sum(
                connections_invested_available[e, s, t]
                for (e, s, t) in connections_invested_available_indices(
                    m; connection=e, stochastic_scenario=s, t=t
                );
                init=0
            )
            + expr_sum(
                storages_invested_available[e, s, t]
                for (e, s, t) in storages_invested_available_indices(m; node=e, stochastic_scenario=s, t=t);
                init=0
            )
            ==
            + expr_sum(
                units_invested_available[other_e, s, t]
                for (other_e, s, t) in units_invested_available_indices(m; unit=other_e, stochastic_scenario=s, t=t);
                init=0
            )
            + expr_sum(
                connections_invested_available[other_e, s, t]
                for (other_e, s, t) in connections_invested_available_indices(
                    m; connection=other_e, stochastic_scenario=s, t=t
                );
                init=0
            )
            + expr_sum(
                storages_invested_available[other_e, s, t]
                for (other_e, s, t) in storages_invested_available_indices(m; node=other_e, stochastic_scenario=s, t=t);
                init=0
            )
        )
        for ig in investment_group()
        for e in _first_entity_investment_group(ig)
        for (e, s, t) in vcat(
            units_invested_available_indices(m; unit=e),
            connections_invested_available_indices(m; connection=e),
            storages_invested_available_indices(m; node=e)
        )
        for other_e in setdiff(_all_entities_investment_group(ig), e)
        for (other_e, s, t) in vcat(
            units_invested_available_indices(m; unit=other_e, stochastic_scenario=s, t=t),
            connections_invested_available_indices(m; connection=other_e, stochastic_scenario=s, t=t),
            storages_invested_available_indices(m; node=other_e, stochastic_scenario=s, t=t),
        )
    )
end

function _all_entities_investment_group(ig)
    vcat(
        unit__investment_group(investment_group=ig),
        connection__investment_group(investment_group=ig),
        node__investment_group(investment_group=ig)
    )
end

function _first_entity_investment_group(ig)
    entities = _all_entities_investment_group(ig)
    isempty(entities) ? () : first(entities)
end