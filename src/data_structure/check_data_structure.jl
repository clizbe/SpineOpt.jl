#############################################################################
# Copyright (C) 2017 - 2020  Spine Project
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

# NOTE: I see some small problem here, related to doing double work.
# For example, checking that the stochastic dags have no loops requires to generate those dags,
# but we can't generate them just for checking and then throw them away, can we?
# So I propose we do that type of checks when we actually generate the corresponding structure.
# And here, we just perform simpler checks that can be done directly on the contents of the db,
# and don't require to build any additional structures.

"""
    _check(cond, err_msg)

Check the conditional `cond` and throws an error with a message `err_msg` if `cond` is `false`.
"""
_check(cond, msg_parts...) = cond || error(msg_parts...)

"""
    _check_warn(cond, err_msg)

Check the conditional `cond` and throws a warning with a message `warn_msg` if `cond` is `false`.
"""
_check_warn(cond, msg_parts...) = cond || @warn string(msg_parts...)

"""
    check_data_structure(log_level::Int64)

Check if the data structure provided from the db results in a valid model.
"""
function check_data_structure(; log_level=3)
    check_model_object()
    check_temporal_block_object()
    check_node_object()
    check_model__node__temporal_block()
    check_model__node__stochastic_structure()
    check_model__unit__stochastic_structure()
    check_minimum_operating_point_unit_capacity()
    # check_islands(; log_level=log_level)
    check_branching_before_rolling()
    check_parameter_values()
end

"""
    check_model_object()

Check if at least one `model` object is defined.
"""
function check_model_object()
    _check(!isempty(model()), "`model` object not found - you need a `model` object to run SpineOpt")
end

"""
    check_temporal_block_object()

Check if at least one `temporal_block` is defined.
"""
function check_temporal_block_object()
    _check(
        !isempty(temporal_block()),
        "`temporal_block` object not found - you need at least one `temporal_block` to run SpineOpt",
    )
end

"""
    check_node_object()

Check if at least one `node` is defined.
"""
function check_node_object()
    for m in model(model_type=:spineopt_standard)
        _check(
            !isempty(node()),
            "`node` object not found - you need at least one `node` to run a SpineOpt Operations Model",
        )
    end
end

"""
    check_model__node__temporal_block()

Check that each `node` has at least one `temporal_block` connected to it in each `model`.
"""
function check_model__node__temporal_block()
    errors = [
        (m, n)
        for m in model(model_type=:spineopt_standard)
        for n in node()
        if n == members(n) && isempty(intersect(node__temporal_block(node=n), model__temporal_block(model=m)))
    ]
    _check(
        isempty(errors),
        "invalid `node__temporal_block` or `model__temporal_block` definitions ",
        "for (`model`, `node`) pair(s): $(join(errors, ", ", " and ")) - ",
        "each `node` must be related to at least one `temporal_block` per `model`",
    )
    errors_group = [
        (m, n)
        for m in model(model_type=:spineopt_standard)
        for n in node()
        if any(isempty, intersect(node__temporal_block(node=members(n)), model__temporal_block(model=m)))
    ]
    _check(
        isempty(errors_group),
        "some `node` group members don't have a `node__temporal_block` or `model__temporal_block` definitions ",
        "for `(model, node)` pair(s): $(join(errors_group, ", ", " and ")) - ",
        "each `node` group member must be related to at least one `temporal_block` per `model`",
    )
    warnings = [
        (m, n)
        for m in model(model_type=:spineopt_standard)
        for n in node()
        if n != members(n) && isempty(intersect(node__temporal_block(node=n), model__temporal_block(model=m)))
    ]
    _check_warn(
        isempty(warnings),
        "some `node` groups don't have a `node__temporal_block` or `model__temporal_block` definitions ",
        "for `(model, node)` pair(s): $(join(warnings, ", ", " and ")) - ",
        "these `node` groups will only be used for aggregation, ",
        "i.e., there will be no variables and balances associated with them",
    )
end

"""
    check_model__node__stochastic_structure()

Ensure there's exactly one `stochastic_structure` active per `node` per `model`.

This is deduced from the `model__stochastic_structure` and `node__stochastic_structure` relationships.
"""
function check_model__node__stochastic_structure()
    errors = [
        (m, n)
        for m in model(model_type=:spineopt_standard) for n in node()
        if length(intersect(node__stochastic_structure(node=n), model__stochastic_structure(model=m))) != 1
        && n == members(n)
    ]
    errors_group = [
        (m, n)
        for m in model(model_type=:spineopt_standard) for n in node()
        for n_mem in members(n)
        if length(intersect(node__stochastic_structure(node=n_mem), model__stochastic_structure(model=m))) != 1
    ]
    warnings = [
        (m, n)
        for m in model(model_type=:spineopt_standard) for n in node()
        if length(intersect(node__stochastic_structure(node=n), model__stochastic_structure(model=m))) != 1
        && n != members(n)
    ]
    _check(
        isempty(errors),
        "invalid `node__stochastic_structure` or `model__stochastic_structure` definitions ",
        "for `(model, node)` pair(s): $(join(errors, ", ", " and ")) - ",
        "each `node` must be related to one and only one `stochastic_structure` per `model`",
    )
    _check(
        isempty(errors_group),
        "some `node` group members don't have exactly one `node__stochastic_structure` ",
        "or `model__stochastic_structure` definitions ",
        "for `(model, node)` pair(s): $(join(errors_group, ", ", " and ")) - ",
        "each `node` group member must be related to one and only one `stochastic_structure` per `model`",
    )
    _check_warn(
        isempty(warnings),
        "some `node` groups don't have a `node__stochastic_structure` or `model__stochastic_structure` definitions ",
        "for `(model, node)` pair(s): $(join(warnings, ", ", " and ")) - ",
        "these `node` groups will only be used for aggregation, ",
        "i.e., there will be no variables and balances associated with them",
    )
end

"""
    check_model__unit__stochastic_structure()

Ensure there's exactly one `stochastic_structure` active per `unit` per `model`.

This is deduced from the `model__stochastic_strucutre` and `units_on__stochastic_structure` relationships.
"""
function check_model__unit__stochastic_structure()
    errors = [
        (m, u)
        for m in model(model_type=:spineopt_standard) for u in unit()
        for u_mem in members(u)
        if length(intersect(units_on__stochastic_structure(unit=u_mem), model__stochastic_structure(model=m))) != 1
    ]
    _check(
        isempty(errors),
        "invalid `units_on__stochastic_structure` or `model__stochastic_structure` definitions ",
        "for `(model, unit)` pair(s): $(join(errors, ", ", " and ")) - ",
        "each `unit` must be related to one and only one `stochastic_structure` per `model`",
    )
end

"""
    check_minimum_operating_point_unit_capacity()

Check if every defined `minimum_operating_point` parameter has a corresponding `unit_capacity` parameter defined.
"""
function check_minimum_operating_point_unit_capacity()
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(minimum_operating_point) if unit_capacity(unit=u, node=n, direction=d) === nothing
    ]
    _check(
        isempty(error_indices),
        "missing `unit_capacity` value for indices: $(join(error_indices, ", ", " and ")) - ",
        "`unit_capacity` must be specified where `minimum_operating_point` is",
    )
end

"""
    check_islands()

Check network for islands and warn the user if problems.
"""
function check_islands(; log_level=3)
    for c in commodity()
        if commodity_physics(commodity=c) in (:commodity_physics_ptdf, :commodity_physics_lodf)
            @timelog log_level 3 "Checking network of commodity $(c) for islands" n_islands, island_node = islands(c)
            @log log_level 3 "The network consists of $(n_islands) islands"
            if n_islands > 1
                @warn "the network of commodity $(c) consists of multiple islands, this may end badly..."
                # add diagnostic option to print island_node which will tell the user which nodes are in which islands
            end
        end
    end
end

"""
    islands()

Determine the number of islands in a commodity network - used for diagnostic purposes.
"""
function islands(c)
    visited_d = Dict{Object,Bool}()
    island_node = Dict{Int64,Array}()
    island_count = 0

    for n in node__commodity(commodity=c)
        visited_d[n] = false
    end

    for n in node__commodity(commodity=c)
        if !visited_d[n]
            island_count = island_count + 1
            island_node[island_count] = Object[]
            visit(n, island_count, visited_d, island_node)
        end
    end
    island_count, island_node
end

"""
    visit()

Recursively visit nodes in the network to determine number of islands.
"""
function visit(n, island_count, visited_d, island_node)
    visited_d[n] = true
    push!(island_node[island_count], n)
    for (conn, n2) in connection__node__node(node1=n)
        if !visited_d[n2]
            visit(n2, island_count, visited_d, island_node)
        end
    end
end

"""
    check_branching_before_rolling()

Check that no `stochastic_structure` branches before `roll_forward`.
"""
function check_branching_before_rolling()
    for m in model()
        rf = roll_forward(model=m, i=1, _strict=false)
        isnothing(rf) && continue
        t0 = model_start(model=m)
        for (ss, scen) in indices(stochastic_scenario_end; stochastic_structure=model__stochastic_structure(model=m))
            scen_end = stochastic_scenario_end(stochastic_structure=ss, stochastic_scenario=scen)
            cond = isnothing(scen_end) || (t0 + scen_end >= t0 + rf)
            _check(
                cond,
                "invalid branching of `stochastic_structure` $ss before `model` $m rolls - ",
                "please make sure that `stochastic_scenario_end` for `stochastic_scenario` $scen ",
                "is larger than `roll_forward` for `model` $m"
            )
        end
    end
end

function check_parameter_values()
    check_model_start_smaller_than_end()
    check_operating_points()
    check_ramping_parameters()
    check_startup_ramps()
    check_shutdown_ramps()
    check_res_startup_ramps()
    check_res_shutdown_ramps()
end

function check_model_start_smaller_than_end()
    for m in indices(model_start)
        _check(model_start(model=m) <= model_end(model=m), "The model start for $(mod) is greater than the model end")
    end
end

function check_operating_points()
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(minimum_operating_point)
        if !(0 <= minimum_operating_point(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "minimum operating point has to be between 0 and 1 for $(join(error_indices, ", ", " and ")) "
    )
end

function check_ramping_parameters()
    # ramp_up_limit between 0 and 1
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(ramp_up_limit) if !(0 < ramp_up_limit(unit=u, node=n, direction=d) <= 1)
    ]

    _check(
        isempty(error_indices),
        "ramp_up_limit has to be between 0 (excl) and 1 for $(join(error_indices, ", ", " and ")) "
    )
    # ramp_down_limit between 0 and 1
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(ramp_down_limit) if !(0 < ramp_down_limit(unit=u, node=n, direction=d) <= 1)
    ]

    _check(
        isempty(error_indices),
        "ramp_down_limit has to be between 0 (excl) and 1 for $(join(error_indices, ", ", " and ")) "
    )
end

function check_startup_ramps()
    # Max Startup ramp between 0 and 1
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(max_startup_ramp) if !(0 < max_startup_ramp(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "max_startup_ramp has to be between 0 (excl) and 1 for $(join(error_indices, ", ", " and ")) "
    )
    # Min Startup ramp between 0 and 1
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(min_startup_ramp) if !(0 <= min_startup_ramp(unit=u, node=n, direction=d) <= 1)
    ]

    _check(
        isempty(error_indices),
        "min_startup_ramp has to be between 0 and 1 for $(join(error_indices, ", ", " and ")) "
    )
    #Max Startup ramp greater than Min startup ramp
    error_indices = [
        (u, n, d)
        for (u, n, d) in intersect(indices(min_startup_ramp),indices(max_startup_ramp))
        if !(min_startup_ramp(unit=u, node=n, direction=d) <= max_startup_ramp(unit=u, node=n, direction=d))
    ]
    _check(
        isempty(error_indices),
        "min_startup_ramp has to be smaller than max_start_up_ramp $(join(error_indices, ", ", " and ")) "
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(max_startup_ramp) if ramp_up_limit(unit=u, node=n, direction=d) === nothing
    ]
    _check(
        isempty(error_indices),
        "missing `ramp_up_limit` value for indices: $(join(error_indices, ", ", " and ")) "
        * "- `ramp_up_limit` must be specified where `max_startup_ramp` is",
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(min_startup_ramp) if ramp_up_limit(unit=u, node=n, direction=d) === nothing
    ]
    _check(
        isempty(error_indices),
        "missing `ramp_up_limit` value for indices: $(join(error_indices, ", ", " and ")) "
        * "- `ramp_up_limit` must be specified where `min_startup_ramp` is",
    )
end

function check_shutdown_ramps()
    # Max shutdown ramp between 0 and 1
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(max_shutdown_ramp) if !(0 < max_shutdown_ramp(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "max_shutdown_ramp has to be between 0 (excl) and 1 for $(join(error_indices, ", ", " and ")) "
    )
    # Min shutdown ramp between 0 and 1
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(min_shutdown_ramp) if !(0 <= min_shutdown_ramp(unit=u, node=n, direction=d) <= 1)
    ]

    _check(
        isempty(error_indices),
        "min_shutdown_ramp has to be between 0 and 1 for $(join(error_indices, ", ", " and ")) "
    )
    #Max shutdown ramp greater than Min startup ramp
    error_indices = [
        (u, n, d)
        for (u, n, d) in intersect(indices(min_shutdown_ramp),indices(max_shutdown_ramp))
        if !(min_shutdown_ramp(unit=u, node=n, direction=d) <= max_shutdown_ramp(unit=u, node=n, direction=d))
    ]
    _check(
        isempty(error_indices),
        "min_shutdown_ramp has to be smaller than max_shutdown_ramp $(join(error_indices, ", ", " and ")) "
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(max_shutdown_ramp) if ramp_down_limit(unit=u, node=n, direction=d) === nothing
    ]
    _check(
        isempty(error_indices),
        "missing `ramp_down_limit` value for indices: $(join(error_indices, ", ", " and ")) "
        * "- `ramp_down_limit` must be specified where `max_shutdown_ramp` is",
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(min_shutdown_ramp) if ramp_down_limit(unit=u, node=n, direction=d) === nothing
    ]
    _check(
        isempty(error_indices),
        string(
            "missing `ramp_down_limit` value for indices: $(join(error_indices, ", ", " and ")) ",
            "- `ramp_down_limit` must be specified where `min_shutdown_ramp` is"
        )
    )
end


function check_res_startup_ramps()
    #Checking that values are within normal boundaries
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(max_res_startup_ramp) if !(0 < max_res_startup_ramp(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "max_res_startup_ramp has to be between 0 (excl) and 1 for $(join(error_indices, ", ", " and ")) "
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(min_res_startup_ramp) if !(0 <= min_res_startup_ramp(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "min_res_startup_ramp has to be between 0 and 1 for $(join(error_indices, ", ", " and ")) "
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in intersect(indices(min_res_startup_ramp),indices(max_res_startup_ramp))
        if !(min_res_startup_ramp(unit=u, node=n, direction=d) <= max_res_startup_ramp(unit=u, node=n, direction=d))
    ]
    _check(
        isempty(error_indices),
        "min_res_startup_ramp has to be smaller than max_res_startup_ramp $(join(error_indices, ", ", " and ")) "
    )
    #Check that node is a reserve node
    #TODO: Should there be checks for upward, downward, spinning, non-spinning?
    error_indices = [
        (u, n, d)
        for (u, n, d) in union(indices(min_res_startup_ramp),indices(max_res_startup_ramp))
        if !(is_reserve_node(node=n))
    ]
    _check(
        isempty(error_indices),
        string(
            "reserve startup ramps have been defined for $(join(error_indices, ", ", " and ")), ",
            "while this is not a reserve node. Please set the is_reserve_node parameter to True"
        )
    )
end

function check_res_shutdown_ramps()
    # Check that values are within normal boundaries
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(max_res_shutdown_ramp)
        if !(0 < max_res_shutdown_ramp(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "max_res_shutdown_ramp has to be between 0 (excl) and 1 for $(join(error_indices, ", ", " and ")) "
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in indices(min_res_shutdown_ramp)
        if !(0 <= min_res_shutdown_ramp(unit=u, node=n, direction=d) <= 1)
    ]
    _check(
        isempty(error_indices),
        "min_res_shutdown_ramp has to be between 0 and 1 for $(join(error_indices, ", ", " and ")) "
    )
    error_indices = [
        (u, n, d)
        for (u, n, d) in intersect(indices(min_res_shutdown_ramp),indices(max_res_shutdown_ramp))
        if !(min_res_shutdown_ramp(unit=u, node=n, direction=d) <= max_res_shutdown_ramp(unit=u, node=n, direction=d))
    ]
    _check(
        isempty(error_indices),
        "min_res_shutdown_ramp has to be smaller than max_res_shutdown_ramp $(join(error_indices, ", ", " and ")) "
    )
    #Check that node is a reserve node
    error_indices = [
        (u, n, d)
        for (u, n, d) in union(indices(min_res_shutdown_ramp),indices(max_res_shutdown_ramp))
        if !(is_reserve_node(node=n))
    ]
    _check(
        isempty(error_indices),
        string(
            "reserve shutdown ramps have been defined for $(join(error_indices, ", ", " and ")), ",
            "while this is not a reserve node. Please set the is_reserve_node parameter to True"
        )
    )
end
