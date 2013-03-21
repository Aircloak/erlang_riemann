Riemann
=======

This is a [riemann](http://riemann.io/) client written in Erlang.
It supports sending events, states, and remotely running queries.

Build status
------------

[![Build Status](https://travis-ci.org/Aircloak/erlang_riemann.png)](https://travis-ci.org/Aircloak/erlang_riemann)

# API

The API is all under the `riemann` module.

    % Shortcut method for sending a service metric:
    riemann:send("meaning of life", 42).

    % If you want to craft a fully custom event,
    % use the event method:
    Opts = [
        {service, "hyperfluxor"}, 
        {state, "ok"}, 
        {metric, 42}, 
        {tags, ["server-8202", "datacentre-12"]}
    ],
    Event = riemann:event(Opts),
    riemann:send(Event).

    % Or alternatively the shortform
    riemann:send_event(Opts).

    % send also accepts lists of events, if you want to 
    % send multiple events in batch.

    % States are very similar to events
    Opts = [
      {service, "pizza oven"},
      {state, "critical"}
    ],
    State = riemann:state(Opts),
    riemann:send(State).


# Installation

Include the `riemann` application in your `rebar.config` file.
Then in your `*.app` file, add `riemann` as a dependent application:

    {application, ...,
     [
      {description, "..."},
      {vsn, "1"},
      {registered, []},
      {applications, [
                      kernel,
                      stdlib,
                      riemann
                     ]},
      {mod, { ..., []}},
      {env, []}
     ]}.

Riemann will default to sending the metrics to localhost on port 5555.
You can set the remote riemann host in your config:

    [
      ...
      {riemann, [
        {host, "riemann.host.com"},
        {port, 5555}
      ]}
    ].

# Contributions

We welcome contributions as pull requests.
Please make a fork of this repository, implement your changes in a feature
branch and make a pull request.

# License

[Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)

# Thanks

- Cameron Bytheway [@CamShaft](https://github.com/CamShaft)
