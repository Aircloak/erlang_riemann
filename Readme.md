Riemann
=======

This is a [riemann](http://riemann.io/) client written in Erlang.
It supports sending events, states, and remotely running queries.

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

# Contributions

We welcome contributions as pull requests.
Please make a fork of this repository, implement your changes in a feature
branch and make a pull request.
