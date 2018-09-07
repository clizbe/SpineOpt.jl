"""
    constraint_max_cum_in_flow_bound(m::Model, flow)

Enforce balance of all commodity flows from and to a node.
TODO: for electrical lines this constraint is obsolete unless
a trade based representation is used.
"""
function constraint_nodal_balance(m::Model, flow, trans)
    @constraint(
        m,
        [
            n in node(),
            t=1:number_of_timesteps(time="timer");
            demand(node=n, t=t) != nothing
        ],
        + sum(flow[c, n, u, "out", t] for u in unit(), c in commodity()
            if [c, n, u] in commodity__node__unit__direction(direction="out"))
        ==
        + demand(node=n, t=t)
        + sum(flow[c, n, u, "in", t] for u in unit(), c in commodity()
            if [c, n, u] in commodity__node__unit__direction(direction="in"))
        + sum(trans[k, n, j, t] for k in connection(), j in node()
            if [k, n, j] in connection__node__node())
    )
    @constraint(
        m,
        [
            n in node(),
            t=1:number_of_timesteps(time="timer");
            demand(node=n, t=t) == nothing
        ],
        + sum(flow[c, n, u, "out", t] for u in unit(), c in commodity()
            if [n, "out"] in commodity__node__unit__direction(unit=u, commodity=c))
        ==
        + sum(flow[c, n, u, "in", t] for u in unit(), c in commodity()
            if [c, n, u] in commodity__node__unit__direction(direction="in"))
        + sum(trans[k, n, j, t] for k in connection(), j in node()
            if [k, n, j] in connection__node__node())
    )
end
