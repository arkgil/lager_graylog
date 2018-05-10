-module(lager_graylog_udp_backend_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-compile(export_all).

-define(HOST, {127, 0, 0, 1}).

%% Suite configuration

all() ->
    [{group, all}].

groups() ->
    [{all, [], test_cases()}].

test_cases() ->
    [sends_log_messages_to_configured_endpoint,
     doesnt_log_over_configured_level
    ].

init_per_suite(Config) ->
    application:set_env(lager, error_logger_redirect, false),
    lager:start(),
    Config.

end_per_suite(_) ->
    application:stop(lager).

init_per_testcase(_, Config) ->
    {Socket, Port} = open(),
    start_lager_handler(Port),
    [{socket, Socket}, {port, Port} | Config].

end_per_testcase(_, Config) ->
    stop_lager_handler(?config(port, Config)).

%% Test cases

sends_log_messages_to_configured_endpoint(Config) ->
    Socket = ?config(socket, Config),

    lager:info("info log message"),
    lager:critical("critical log message"),

    ok = recv(Socket),
    ok = recv(Socket),
    nothing = recv(Socket).

doesnt_log_over_configured_level(Config) ->
    Socket = ?config(socket, Config),

    lager:info("log message"),
    ok = recv(Socket),

    ok = lager:set_loglevel(handler_id(?config(port, Config)), warning),

    lager:info("log message"),
    nothing = recv(Socket).

%% Helpers

-spec start_lager_handler(inet:port_number()) -> ok.
start_lager_handler(Port) ->
    Opts = [{host, ?HOST}, {port, Port}],
    ok = gen_event:add_handler(lager_event, handler_id(Port), Opts).

-spec stop_lager_handler(inet:port_number()) -> ok.
stop_lager_handler(Port) ->
    ok = gen_event:delete_handler(lager_event, handler_id(Port), []).

-spec handler_id(inet:port_number()) -> term().
handler_id(Port) ->
    {lager_graylog_udp_backend, {?HOST, Port}}.

-spec open() -> {gen_udp:socket(), inet:port_number()}.
open() ->
    {ok, Socket} = gen_udp:open(0, [binary,
                                    {ip, ?HOST},
                                    {active, true},
                                    {reuseaddr, true}]),
    {ok, Port} = inet:port(Socket),
    {Socket, Port}.

-spec recv(gen_udp:socket()) -> ok | nothing.
recv(Socket) ->
    recv(Socket, 10, 50).

-spec recv(gen_udp:socket(), Tries :: non_neg_integer(), timeout()) -> ok | nothing.
recv(Socket, Tries, Timeout) when Tries > 0 ->
    receive
        {udp, Socket, _, _, _} ->
            ok
    after
        Timeout ->
            recv(Socket, Tries - 1, Timeout)
    end;
recv(_Socket, 0, _Timeout) ->
    nothing.

