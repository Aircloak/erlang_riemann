-ifndef(STATE_PB_H).
-define(STATE_PB_H, true).
-record(state, {
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

-ifndef(EVENT_PB_H).
-define(EVENT_PB_H, true).
-record(event, {
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

-ifndef(RQUERY_PB_H).
-define(RQUERY_PB_H, true).
-record(rquery, {
    string
}).
-endif.

-ifndef(MSG_PB_H).
-define(MSG_PB_H, true).
-record(msg, {
    ok,
    error,
    states = [],
    pb_query,
    events = []
}).
-endif.

-ifndef(ATTRIBUTE_PB_H).
-define(ATTRIBUTE_PB_H, true).
-record(attribute, {
    key = erlang:error({required, key}),
    value
}).
-endif.

