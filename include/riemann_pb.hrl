-ifndef(RIEMANNSTATE_PB_H).
-define(RIEMANNSTATE_PB_H, true).
-record(riemannstate, {
    time,
    state,
    service,
    host,
    description,
    once,
    tags = [],
    ttl
}).
-endif.

-ifndef(RIEMANNEVENT_PB_H).
-define(RIEMANNEVENT_PB_H, true).
-record(riemannevent, {
    time,
    state,
    service,
    host,
    description,
    tags = [],
    ttl,
    attributes = [],
    metric_sint64,
    metric_d,
    metric_f
}).
-endif.

-ifndef(RIEMANNQUERY_PB_H).
-define(RIEMANNQUERY_PB_H, true).
-record(riemannquery, {
    string
}).
-endif.

-ifndef(RIEMANNMSG_PB_H).
-define(RIEMANNMSG_PB_H, true).
-record(riemannmsg, {
    ok,
    error,
    states = [],
    pb_query,
    events = []
}).
-endif.

-ifndef(RIEMANNATTRIBUTE_PB_H).
-define(RIEMANNATTRIBUTE_PB_H, true).
-record(riemannattribute, {
    key = erlang:error({required, key}),
    value
}).
-endif.

