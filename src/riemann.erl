-module(riemann).

-behaviour(gen_server).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% API
-export([
  start/0,
  start_link/0,
  send/1,
  event/1,
  send_event/1,
  sge/0
]).

%% gen_server callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

-include("riemann_pb.hrl").

-record(srv_state, {
    tcp_socket,
    udp_socket,
    host,
    port
}).

-define(UDP_MAX_SIZE, 16384).

-type riemann_event() :: #riemannevent{}.
-type send_response() :: ok | {error, _Reason}.

-type event_metric() :: {metric, number()}.
-type event_time() :: {time, non_neg_integer()}.
-type event_state() :: {state, string()}.
-type event_service() :: {service, string()}.
-type event_host() :: {host, string()}.
-type event_description() :: {description, string()}.
-type event_tags() :: {tags, [string()]}.
-type event_ttl() :: {ttl, float()}.
-type event_attributes() :: {attributes, [{string(), string()}]}.
-type event_opts() :: 
    event_metric()
  | event_time() 
  | event_state() 
  | event_service() 
  | event_host() 
  | event_description() 
  | event_tags() 
  | event_ttl() 
  | event_attributes().

%%%===================================================================
%%% API
%%%===================================================================

sge() ->
  send([event([{service, "test"}, {metric,10}]) || _ <- lists:seq(1,1000)]).

start() ->
  application:start(?MODULE).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Creates a riemann event. It does not send it to the riemann server.
-spec event([event_opts()]) -> riemann_event().
event(Vals) ->
  create_event(Vals).

%% @doc Shortcut for creating and sending an event in one go
-spec send_event([event_opts()]) -> send_response().
send_event(Vals) ->
  send([create_event(Vals)]).

%% @doc Sends an event, or a list of events to the riemann server 
%%      the application is connected to.
-spec send([riemann_event()] | riemann_event()) -> send_response().
send(#riemannevent{}=Event) -> send([Event]);
send(Events) ->
  gen_server:call(?MODULE, {send, Events}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
  case setup_riemann_connectivity(#srv_state{}) of
    {error, Reason} ->
      lager:error("Could not setup connections to riemann: ~p", [Reason]),
      {stop, {shutdown, Reason}};
    Other -> Other
  end.

handle_call({send, Events}, _From, S0) ->
  {Reply, S1} = send_events(Events, S0),
  {reply, Reply, S1};

handle_call(_Request, _From, State) ->
  Reply = ok,
  {reply, Reply, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, #srv_state{udp_socket=UdpSocket, tcp_socket=TcpSocket}) ->
  gen_udp:close(UdpSocket),
  gen_tcp:close(TcpSocket),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

setup_riemann_connectivity(S) ->
  Host = get_env(host, "127.0.0.1"),
  Port = get_env(port, 5555),
  setup_udp_socket(S#srv_state{
    host = Host,
    port = Port
  }).

setup_udp_socket(#srv_state{udp_socket = undefined}=S) ->
  {ok, UdpSocket} = gen_udp:open(0, [binary, {active,false}]),
  setup_tcp_socket(S#srv_state{udp_socket = UdpSocket});
setup_udp_socket(S) ->
  setup_tcp_socket(S).

setup_tcp_socket(#srv_state{tcp_socket=undefined, host=Host, port=Port}=S) ->
  Options = [binary, {active,false}, {keepalive, true}, {nodelay, true}],
  Timeout = 10000,
  case gen_tcp:connect(Host, Port, Options, Timeout) of
    {ok, TcpSocket} ->
      ok = gen_tcp:controlling_process(TcpSocket, self()),
      {ok, S#srv_state{tcp_socket = TcpSocket}};
    {error, Reason} ->
      lager:error("Failed opening a Tcp socket to riemann with reason ~p", [Reason]),
      {error, Reason}
  end;
setup_tcp_socket(S) -> S.

get_env(Name, Default) ->
  case application:get_env(riemann, Name) of
    {ok, V} -> V;
    _ -> Default
  end.

send_events(Events, State) ->
  Msg = #riemannmsg{events = Events},
  BinMsg = riemann_pb:encode_msg(Msg),
  case byte_size(BinMsg) > ?UDP_MAX_SIZE of
    true -> 
      send_with_tcp(BinMsg, State);
    false ->
      {send_with_udp(BinMsg, State), State}
  end.

send_with_tcp(Msg, #srv_state{tcp_socket=TcpSocket}=S) ->
  MessageSize = byte_size(Msg),
  MsgWithLength = <<MessageSize:32/integer-big, Msg/binary>>,
  case gen_tcp:send(TcpSocket, MsgWithLength) of
    ok ->
      {await_reply(TcpSocket), S};
    {error, closed} ->
      lager:info("Connection to riemann is closed. Reestablishing connection."),
      case setup_riemann_connectivity(S#srv_state{tcp_socket = undefined}) of
        {ok, S1} ->
          send_with_tcp(Msg, S1);
        {error, Reason} ->
          lager:error("Re-establishing a tcp connection to riemann failed because of ~p", [Reason]),
          {{error, Reason}, S}
      end;
    {error, Reason} ->
      lager:error("Failed sending event to riemann with reason: ~p", [Reason]),
      {{error, Reason}, S}
  end.

await_reply(TcpSocket) ->
  case gen_tcp:recv(TcpSocket, 0, 3000) of
    {ok, BinResp} ->
      case decode_response(BinResp) of
        #riemannmsg{ok=true} -> ok;
        #riemannmsg{ok=false, error=Reason} -> {error, Reason}
      end;
    Other -> Other
  end.

decode_response(<<MsgLength:32/integer-big, Data/binary>>) ->
  case Data of
    <<Msg:MsgLength/binary, _/binary>> ->
      riemann_pb:decode_msg(Msg);
    _ ->
      lager:error("Failed at decoding response from riemann"),
      #riemannmsg{
        ok = false,
        error = "Decoding response from Riemann failed"
      }
  end.

send_with_udp(Msg, #srv_state{udp_socket=UdpSocket, host=Host, port=Port}) ->
  gen_udp:send(UdpSocket, Host, Port, Msg).

create_event(Vals) ->
  create_base_event(Vals, #riemannevent{}).

create_base_event(Vals, Event) ->
  Event1 = lists:foldl(fun(Key, E) ->
          case proplists:get_value(Key, Vals) of
            undefined -> E;
            Value -> set_val(Key, Value, E)
          end
      end, Event, [time, state, service, host, description, tags, ttl, attributes]),
  Event2 = add_metric_value(Vals, Event1),
  set_default_host(Event2).

set_val(time, V, E) -> E#riemannevent{time=V};
set_val(state, V, E) -> E#riemannevent{state=V};
set_val(service, V, E) -> E#riemannevent{service=V};
set_val(host, V, E) -> E#riemannevent{host=V};
set_val(description, V, E) -> E#riemannevent{description=V};
set_val(tags, V, E) -> E#riemannevent{tags=V};
set_val(ttl, V, E) -> E#riemannevent{ttl=V};
set_val(attributes, V, E) -> E#riemannevent{attributes=V}.

add_metric_value(Vals, Event) ->
  case proplists:get_value(metric, Vals, 0) of
    V when is_integer(V) ->
      Event#riemannevent{metric_f = V * 1.0, metric_sint64 = V};
    V ->
      Event#riemannevent{metric_f = V, metric_d = V}
  end.

set_default_host(Event) ->
  case Event#riemannevent.host of
    undefined -> Event#riemannevent{host = default_node_name()};
    _ -> Event
  end.

default_node_name() ->
  atom_to_list(node()).

%%%===================================================================
%%% Tests
%%%===================================================================

-ifdef(TEST).

e() ->
  #riemannevent{metric_f = 0.0}.

create_base_event_test() ->
  CE = fun(Ps) -> create_base_event(Ps, e()) end,
  ?assertEqual(1, (CE([{time,1}]))#riemannevent.time),
  ?assertEqual("ok", (CE([{state,"ok"}]))#riemannevent.state),
  ?assertEqual("test", (CE([{service,"test"}]))#riemannevent.service),
  ?assertEqual("host1", (CE([{host,"host1"}]))#riemannevent.host),
  ?assertEqual("desc", (CE([{description,"desc"}]))#riemannevent.description),
  ?assertEqual(["one", "two"], (CE([{tags,["one", "two"]}]))#riemannevent.tags),
  ?assertEqual(1.0, (CE([{ttl,1.0}]))#riemannevent.ttl),
  ?assertEqual([#riemannattribute{key="key"}], 
               (CE([{attributes,[#riemannattribute{key="key"}]}]))#riemannevent.attributes).

set_metric_value_test() ->
  AM = fun(Ps) -> add_metric_value(Ps, #riemannevent{metric_f = 0.0}) end,
  E1 = AM([{metric, 1}]),
  ?assertEqual(1, E1#riemannevent.metric_sint64),
  ?assertEqual(1.0, E1#riemannevent.metric_f),
  E2 = AM([{metric, 1.0}]),
  ?assertEqual(1.0, E2#riemannevent.metric_d),
  ?assertEqual(1.0, E2#riemannevent.metric_f).

default_node_name_test() ->
  ?assertEqual("nonode@nohost", default_node_name()).

set_default_host_test() ->
  E = #riemannevent{host = "host"},
  E1 = set_default_host(E),
  ?assertEqual("host", E1#riemannevent.host),
  E2 = set_default_host(#riemannevent{}),
  ?assertEqual(default_node_name(), E2#riemannevent.host).

-endif.
