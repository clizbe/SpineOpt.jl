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
    add_constraint_connection_flow_lodf!(m::Model)

Limit the post contingency flow on monitored connection mon to conn_emergency_capacity upon outage of connection cont.
"""
function add_constraint_connection_flow_lodf!(m::Model)
    rpts = join(get(m.ext[:spineopt].reports_by_output, output(:contingency_is_binding), []), ", ", " and ")
    if !isempty(rpts)
        @info "skipping constraint connection_flow_lodf - instead will report contingency_is_binding in $rpts"
        return
    end
    t0 = _analysis_time(m)
    @fetch connection_flow = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:connection_flow_lodf] = Dict(
        (connection_contingency=conn_cont, connection_monitored=conn_mon, stochastic_path=s, t=t) => @constraint(
            m,
            - connection_minimum_emergency_capacity(m, conn_mon, s, t)
            <=
            + connection_post_contingency_flow(m, connection_flow, conn_cont, conn_mon, s, t, expr_sum)
              * connection_availability_factor[(connection=conn_mon, stochastic_scenario=s, analysis_time=t0, t=t)]
            <=
            + connection_minimum_emergency_capacity(m, conn_mon, s, t)
        )
        for (conn_cont, conn_mon, s, t) in constraint_connection_flow_lodf_indices(m)
    )
end

function connection_post_contingency_flow(m, connection_flow, conn_cont, conn_mon, s, t, sum=sum)
    (
        # flow in monitored connection
        sum(
            + connection_flow[conn_mon, n_mon_to, direction(:to_node), s, t_short]
            - connection_flow[conn_mon, n_mon_to, direction(:from_node), s, t_short]
            for (conn_mon, n_mon_to, d, s, t_short) in connection_flow_indices(
                m;
                connection=conn_mon,
                last(connection__from_node(connection=conn_mon))...,
                stochastic_scenario=s,
                t=t_in_t(m; t_long=t),
            ); # NOTE: always assume the second (last) node in `connection__from_node` is the 'to' node
            init=0,
        )
        # excess flow due to outage on contingency connection
        + lodf[(connection1=conn_cont, connection2=conn_mon, t=t)]
        * sum(
            + connection_flow[conn_cont, n_cont_to, direction(:to_node), s, t_short]
            - connection_flow[conn_cont, n_cont_to, direction(:from_node), s, t_short]
            for (conn_cont, n_cont_to, d, s, t_short) in connection_flow_indices(
                m;
                connection=conn_cont,
                last(connection__from_node(connection=conn_cont))...,
                stochastic_scenario=s,
                t=t_in_t(m; t_long=t),
            ); # NOTE: always assume the second (last) node in `connection__from_node` is the 'to' node
            init=0,
        )
    )
end

function connection_minimum_emergency_capacity(m, conn_mon, s, t)
    t0 = _analysis_time(m)
    minimum(
        + connection_emergency_capacity[
            (connection=conn_mon, node=n_mon, direction=d, stochastic_scenario=s, analysis_time=t0, t=t),
        ]
        * connection_availability_factor[(connection=conn_mon, stochastic_scenario=s, analysis_time=t0, t=t)]
        * connection_conv_cap_to_flow[
            (connection=conn_mon, node=n_mon, direction=d, stochastic_scenario=s, analysis_time=t0, t=t),
        ]
        for (conn_mon, n_mon, d) in indices(connection_emergency_capacity; connection=conn_mon)
        for s in s
    )
end

function constraint_connection_flow_lodf_indices(m::Model)
    unique(
        (connection_contingency=conn_cont, connection_monitored=conn_mon, stochastic_path=path, t=t)
        for (conn_cont, conn_mon) in lodf_connection__connection()
        if all(
            [
                connection_contingency(connection=conn_cont) === true,
                connection_monitored(connection=conn_mon) === true,
                has_lodf(connection=conn_cont),
                has_lodf(connection=conn_mon)
            ]
        )
        for (t, path) in t_lowest_resolution_path(
            m, 
            x
            for conn in (conn_cont, conn_mon)
            for x in connection_flow_indices(m; connection=conn, last(connection__from_node(connection=conn))...)
        )
    )
end

"""
    constraint_connection_flow_lodf_indices_filtered(m::Model; filtering_options...)

Form the stochastic indexing Array for the `:connection_flow_lodf` constraint.

Uses stochastic path indices due to potentially different stochastic structures between `connection_flow` variables.
Keyword arguments can be used for filtering the resulting Array.
"""
function constraint_connection_flow_lodf_indices_filtered(
    m::Model;
    connection_contingency=anything,
    connection_monitored=anything,
    stochastic_path=anything,
    t=anything,
)
    function f(ind)
        _index_in(
            ind;
            connection_contingency=connection_contingency,
            connection_monitored=connection_monitored,
            stochastic_path=stochastic_path,
            t=t,
        )
    end
    filter(f, constraint_connection_flow_lodf_indices(m))
end
