%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqtt_bench).

-export([ main/1
        , main/2
        , start/2
        , run/3
        , connect/4
        , loop/5
        ]).

-define(PUB_OPTS,
        [{help, undefined, "help", boolean,
          "help information"},
         {host, $h, "host", {string, "localhost"},
          "mqtt server hostname or IP address"},
         {port, $p, "port", {integer, 1883},
          "mqtt server port number"},
         {version, $V, "version", {integer, 5},
          "mqtt protocol version: 3 | 4 | 5"},
         {count, $c, "count", {integer, 200},
          "max count of clients"},
         {startnumber, $n, "startnumber", {integer, 0}, "start number"},
         {interval, $i, "interval", {integer, 10},
          "interval of connecting to the broker"},
         {interval_of_msg, $I, "interval_of_msg", {integer, 1000},
          "interval of publishing message(ms)"},
         {username, $u, "username", string,
          "username for connecting to server"},
         {password, $P, "password", string,
          "password for connecting to server"},
         {topic, $t, "topic", string,
          "topic subscribe, support %u, %c, %i variables"},
         {size, $s, "size", {integer, 256},
          "payload size"},
         {qos, $q, "qos", {integer, 0},
          "subscribe qos"},
         {retain, $r, "retain", {boolean, false},
          "retain message"},
         {keepalive, $k, "keepalive", {integer, 300},
          "keep alive in seconds"},
         {clean, $C, "clean", {boolean, true},
          "clean start"},
         {limit, $L, "limit", {integer, 0},
          "The max message count to publish, 0 means unlimited"},
         {ssl, $S, "ssl", {boolean, false},
          "ssl socoket for connecting to server"},
         {certfile, undefined, "certfile", string,
          "client certificate for authentication, if required by server"},
         {keyfile, undefined, "keyfile", string,
          "client private key for authentication, if required by server"},
         {ws, undefined, "ws", {boolean, false},
          "websocket transport"},
         {quic, undefined, "quic", {boolean, false},
          "QUIC transport"},
         {ifaddr, undefined, "ifaddr", string,
          "One or multiple (comma-separated) source IP addresses"},
         {prefix, undefined, "prefix", string, "client id prefix"},
         {lowmem, $l, "lowmem", boolean, "enable low mem mode, but use more CPU"}
        ]).

-define(SUB_OPTS,
        [{help, undefined, "help", boolean,
          "help information"},
         {host, $h, "host", {string, "localhost"},
          "mqtt server hostname or IP address"},
         {port, $p, "port", {integer, 1883},
          "mqtt server port number"},
         {version, $V, "version", {integer, 5},
          "mqtt protocol version: 3 | 4 | 5"},
         {count, $c, "count", {integer, 200},
          "max count of clients"},
         {startnumber, $n, "startnumber", {integer, 0}, "start number"},
         {interval, $i, "interval", {integer, 10},
          "interval of connecting to the broker"},
         {topic, $t, "topic", string,
          "topic subscribe, support %u, %c, %i variables"},
         {qos, $q, "qos", {integer, 0},
          "subscribe qos"},
         {username, $u, "username", string,
          "username for connecting to server, support %i variable"},
         {password, $P, "password", string,
          "password for connecting to server"},
         {keepalive, $k, "keepalive", {integer, 300},
          "keep alive in seconds"},
         {clean, $C, "clean", {boolean, true},
          "clean start"},
         {ssl, $S, "ssl", {boolean, false},
          "ssl socoket for connecting to server"},
         {certfile, undefined, "certfile", string,
          "client certificate for authentication, if required by server"},
         {keyfile, undefined, "keyfile", string,
          "client private key for authentication, if required by server"},
         {ws, undefined, "ws", {boolean, false},
          "websocket transport"},
         {quic, undefined, "quic", {boolean, false},
          "QUIC transport"},
         {ifaddr, undefined, "ifaddr", string,
          "local ipaddress or interface address"},
         {prefix, undefined, "prefix", string, "client id prefix"},
         {lowmem, $l, "lowmem", boolean, "enable low mem mode, but use more CPU"}
        ]).

-define(CONN_OPTS, [
         {help, undefined, "help", boolean,
          "help information"},
         {host, $h, "host", {string, "localhost"},
          "mqtt server hostname or IP address"},
         {port, $p, "port", {integer, 1883},
          "mqtt server port number"},
         {version, $V, "version", {integer, 5},
          "mqtt protocol version: 3 | 4 | 5"},
         {count, $c, "count", {integer, 200},
          "max count of clients"},
         {startnumber, $n, "startnumber", {integer, 0}, "start number"},
         {interval, $i, "interval", {integer, 10},
          "interval of connecting to the broker"},
         {username, $u, "username", string,
          "username for connecting to server"},
         {password, $P, "password", string,
          "password for connecting to server"},
         {keepalive, $k, "keepalive", {integer, 300},
          "keep alive in seconds"},
         {clean, $C, "clean", {boolean, true},
          "clean session"},
         {ssl, $S, "ssl", {boolean, false},
          "ssl socoket for connecting to server"},
         {certfile, undefined, "certfile", string,
          "client certificate for authentication, if required by server"},
         {keyfile, undefined, "keyfile", string,
          "client private key for authentication, if required by server"},
         {quic, undefined, "quic", {boolean, false},
          "QUIC transport"},
         {ifaddr, undefined, "ifaddr", string,
          "local ipaddress or interface address"},
         {prefix, undefined, "prefix", string, "client id prefix"},
         {lowmem, $l, "lowmem", boolean, "enable low mem mode, but use more CPU"}
        ]).

-define(TAB, ?MODULE).
-define(COUNTERS, 16).
-define(IDX_SENT, 1).
-define(IDX_RECV, 2).
-define(IDX_SUB, 3).
-define(IDX_SUB_FAIL, 4).
-define(IDX_PUB, 5).
-define(IDX_PUB_FAIL, 6).

main(["sub"|Argv]) ->
    {ok, {Opts, _Args}} = getopt:parse(?SUB_OPTS, Argv),
    ok = maybe_help(sub, Opts),
    ok = check_required_args(sub, [count, topic], Opts),
    main(sub, Opts);

main(["pub"|Argv]) ->
    {ok, {Opts, _Args}} = getopt:parse(?PUB_OPTS, Argv),
    ok = maybe_help(pub, Opts),
    ok = check_required_args(pub, [count, topic], Opts),
    main(pub, Opts);

main(["conn"|Argv]) ->
    {ok, {Opts, _Args}} = getopt:parse(?CONN_OPTS, Argv),
    ok = maybe_help(conn, Opts),
    ok = check_required_args(conn, [count], Opts),
    main(conn, Opts);

main(_Argv) ->
    ScriptPath = escript:script_name(),
    Script = filename:basename(ScriptPath),
    io:format("Usage: ~s pub | sub | conn [--help]~n", [Script]).

maybe_help(PubSub, Opts) ->
    case proplists:get_value(help, Opts) of
        true ->
            usage(PubSub),
            halt(0);
        _ -> ok
    end.

check_required_args(PubSub, Keys, Opts) ->
    lists:foreach(fun(Key) ->
        case lists:keyfind(Key, 1, Opts) of
            false ->
                io:format("Error: '~s' required~n", [Key]),
                usage(PubSub),
                halt(1);
            _ -> ok
        end
    end, Keys).

usage(PubSub) ->
    ScriptPath = escript:script_name(),
    Script = filename:basename(ScriptPath),
    Opts = case PubSub of
               pub -> ?PUB_OPTS;
               sub -> ?SUB_OPTS;
               conn -> ?CONN_OPTS
           end,
    getopt:usage(Opts, Script ++ " " ++ atom_to_list(PubSub)).

main(sub, Opts) ->
    start(sub, Opts);

main(pub, Opts) ->
    Size    = proplists:get_value(size, Opts),
    Payload = iolist_to_binary([O || O <- lists:duplicate(Size, $a)]),
    MsgLimit = consumer_pub_msg_fun_init(proplists:get_value(limit, Opts)),
    start(pub, [{payload, Payload}, {limit_fun, MsgLimit} | Opts]);

main(conn, Opts) ->
    start(conn, Opts).

start(PubSub, Opts) ->
    prepare(), init(),
    IfAddr = proplists:get_value(ifaddr, Opts),
    AddrList = case IfAddr =/= undefined andalso lists:member($,, IfAddr) of
                    false ->
                        [IfAddr];
                    true ->
                       string:tokens(IfAddr, ",")
                end,
    NoWorkers = length(AddrList),
    Count = proplists:get_value(count, Opts),
    CntPerWorker = Count div NoWorkers,
    Rem = Count rem NoWorkers,
    Interval = proplists:get_value(interval, Opts) * NoWorkers,
    MsgInterval = proplists:get_value(interval_of_msg, Opts, 1000) * NoWorkers,
    lists:foreach(fun(P) ->
                          StartNumber = proplists:get_value(startnumber, Opts) + CntPerWorker*P,
                          CountParm = case Rem =/= 0 andalso P == 1 of
                                          true ->
                                              [{count, CntPerWorker + Rem}];
                                          false ->
                                              [{count, CntPerWorker}]
                                      end,
                          WOpts = replace_opts(Opts, [{startnumber, StartNumber},
                                                      {ifaddr, lists:nth(P, AddrList)},
                                                      {interval_of_msg, MsgInterval},
                                                      {interval, Interval}
                                                     ] ++ CountParm),
                          spawn(?MODULE, run, [self(), PubSub, WOpts])
                  end, lists:seq(1, NoWorkers)),
    timer:send_interval(1000, stats),
    main_loop(os:timestamp(), 1+proplists:get_value(startnumber, Opts)).

prepare() ->
    Sname = list_to_atom(lists:flatten(io_lib:format("~p-~p", [?MODULE, rand:uniform(1000)]))),
    net_kernel:start([Sname, shortnames]),
    {ok, _} = application:ensure_all_started(quicer),
    application:ensure_all_started(emqtt_bench).

init() ->
    process_flag(trap_exit, true),
    CRef = counters:new(?COUNTERS, [write_concurrency]),
    ok = persistent_term:put(?MODULE, CRef),
    put({stats, recv}, 0),
    put({stats, sent}, 0),
    put({stats, pub}, 0),
    put({stats, pub_fail}, 0),
    put({stats, sub_fail}, 0),
    put({stats, sub}, 0).


main_loop(Uptime, Count) ->
    receive
        publish_complete ->
            return_print("publish complete", []);
        {connected, _N, _Client} ->
            return_print("connected: ~w", [Count]),
            main_loop(Uptime, Count+1);
        stats ->
            print_stats(Uptime),
            main_loop(Uptime, Count);
        Msg ->
            print("~p~n", [Msg]),
            main_loop(Uptime, Count)
    end.

print_stats(Uptime) ->
    [print_stats(Uptime, Cnt) ||
        Cnt <- [sent, recv, sub, pub, sub_fail, pub_fail]],
    ok.

print_stats(Uptime, Name) ->
    CurVal = get_counter(Name),
    LastVal = get({stats, Name}),
    case CurVal == LastVal of
        false ->
            Tdiff = timer:now_diff(os:timestamp(), Uptime) div 1000,
            print("~s(~w): total=~w, rate=~w(msg/sec)~n",
                  [Name, Tdiff, CurVal, CurVal - LastVal]),
            put({stats, Name}, CurVal);
        true -> ok
    end.

%% this is only used for main loop
return_print(Fmt, Args) ->
    print(return, Fmt, Args).

print(Fmt, Args) ->
    print(feed, Fmt, Args).

print(ReturnMaybeFeed, Fmt, Args) ->
    % print the return
    io:format("\r"),
    maybe_feed(ReturnMaybeFeed),
    io:format(Fmt, Args).

maybe_feed(ReturnMaybeFeed) ->
    Last = get(?FUNCTION_NAME),
    maybe_feed(Last, ReturnMaybeFeed),
    put(?FUNCTION_NAME, ReturnMaybeFeed).

maybe_feed(return, feed) -> io:format("\n");
maybe_feed(_, _) -> ok.

get_counter(sent) ->
    counters:get(cnt_ref(), ?IDX_SENT);
get_counter(recv) ->
    counters:get(cnt_ref(), ?IDX_RECV);
get_counter(sub) ->
    counters:get(cnt_ref(), ?IDX_SUB);
get_counter(pub) ->
    counters:get(cnt_ref(), ?IDX_PUB);
get_counter(sub_fail) ->
    counters:get(cnt_ref(), ?IDX_SUB_FAIL);
get_counter(pub_fail) ->
    counters:get(cnt_ref(), ?IDX_PUB_FAIL).

inc_counter(sent) ->
    counters:add(cnt_ref(), ?IDX_SENT, 1);
inc_counter(recv) ->
    counters:add(cnt_ref(), ?IDX_RECV, 1);
inc_counter(sub) ->
    counters:add(cnt_ref(), ?IDX_SUB, 1);
inc_counter(sub_fail) ->
    counters:add(cnt_ref(), ?IDX_SUB_FAIL, 1);
inc_counter(pub) ->
    counters:add(cnt_ref(), ?IDX_PUB, 1);
inc_counter(pub_fail) ->
    counters:add(cnt_ref(), ?IDX_PUB_FAIL, 1).


-compile({inline, [cnt_ref/0]}).
cnt_ref() -> persistent_term:get(?MODULE).

run(Parent, PubSub, Opts) ->
    run(Parent, proplists:get_value(count, Opts), PubSub, Opts).

run(_Parent, 0, _PubSub, _Opts) ->
    done;
run(Parent, N, PubSub, Opts) ->
    SpawnOpts = case proplists:get_bool(lowmem, Opts) of
                    true ->
                        [{min_heap_size, 16}, {min_bin_vheap_size, 16}];
                    false ->
                        []
                end,
    spawn_opt(?MODULE, connect, [Parent, N+proplists:get_value(startnumber, Opts), PubSub, Opts],
             SpawnOpts),
	timer:sleep(proplists:get_value(interval, Opts)),
	run(Parent, N-1, PubSub, Opts).

connect(Parent, N, PubSub, Opts) ->
    process_flag(trap_exit, true),
    rand:seed(exsplus, erlang:timestamp()),
    ClientId = client_id(PubSub, N, Opts),
    MqttOpts = [{clientid, ClientId},
                {tcp_opts, tcp_opts(Opts)},
                {ssl_opts, ssl_opts(Opts)}
               | mqtt_opts(Opts)],
    MqttOpts1 = interpolate_username(MqttOpts, N),
    MqttOpts2 = case PubSub of
                  conn -> [{force_ping, true} | MqttOpts1];
                  _ -> MqttOpts1
                end,
    AllOpts  = [{seq, N}, {client_id, ClientId} | Opts],
	{ok, Client} = emqtt:start_link(MqttOpts2),
    ConnectFun = connect_fun(Opts),
    ConnRet = emqtt:ConnectFun(Client),
    case ConnRet of
        {ok, _Props} ->
            Parent ! {connected, N, Client},
            case PubSub of
                conn -> ok;
                sub ->
                    subscribe(Client, AllOpts);
                pub ->
                   Interval = proplists:get_value(interval_of_msg, Opts),
                   timer:send_interval(Interval, publish)
            end,
            loop(Parent, N, Client, PubSub, loop_opts(AllOpts));
        {error, Error} ->
            io:format("client(~w): connect error - ~p~n", [N, Error])
    end.

loop(Parent, N, Client, PubSub, Opts) ->
    receive
        publish ->
           case (proplists:get_value(limit_fun, Opts))() of
                true ->
                    case publish(Client, Opts) of
                        ok -> inc_counter(sent);
                        {ok, _} ->
                            inc_counter(sent);
                        {error, Reason} ->
                            io:format("client(~w): publish error - ~p~n", [N, Reason])
                    end,
                    loop(Parent, N, Client, PubSub, Opts);
                _ ->
                    Parent ! publish_complete,
                    exit(normal)
            end;
        {publish, _Publish} ->
            inc_counter(recv),
            loop(Parent, N, Client, PubSub, Opts);
        {'EXIT', Client, normal} ->
            ok;
        {'EXIT', Client, Reason} ->
            io:format("client(~w): EXIT for ~p~n", [N, Reason])
    after
        500 ->
            case proplists:get_bool(lowmem, Opts) of
                true ->
                    erlang:garbage_collect(Client, [{type, major}]),
                    erlang:garbage_collect(self(), [{type, major}]);
                false ->
                    skip
            end,
            proc_lib:hibernate(?MODULE, loop, [Parent, N, Client, PubSub, Opts])
	end.

consumer_pub_msg_fun_init(0) ->
    fun() -> true end;
consumer_pub_msg_fun_init(N) when is_integer(N), N > 0 ->
    Ref = counters:new(1, []),
    counters:put(Ref, 1, N),
    fun() ->
        case counters:get(Ref, 1) of
            0 -> false;
            _ ->
                counters:sub(Ref, 1, 1), true
        end
    end.

subscribe(Client, Opts) ->
    Qos = proplists:get_value(qos, Opts),
    Res = emqtt:subscribe(Client, [{Topic, Qos} || Topic <- topics_opt(Opts)]),
    case Res of
        {ok, _, _} ->
            inc_counter(sub);
        {error, _Reason} ->
            inc_counter(sub_fail),
            emqtt:disconnect(Client, sub_fail)
    end,
    Res.

publish(Client, Opts) ->
    Flags   = [{qos, proplists:get_value(qos, Opts)},
               {retain, proplists:get_value(retain, Opts)}],
    Payload = proplists:get_value(payload, Opts),
    Res = emqtt:publish(Client, topic_opt(Opts), Payload, Flags),
    case Res of
        ok ->
            inc_counter(pub);
        {ok,_} ->
            inc_counter(pub);
        {error, _} ->
            inc_counter(pub_fail)
    end,
    Res.

mqtt_opts(Opts) ->
    mqtt_opts(Opts, []).

mqtt_opts([], Acc) ->
    Acc;
mqtt_opts([{host, Host}|Opts], Acc) ->
    mqtt_opts(Opts, [{host, Host}|Acc]);
mqtt_opts([{port, Port}|Opts], Acc) ->
    mqtt_opts(Opts, [{port, Port}|Acc]);
mqtt_opts([{version, 3}|Opts], Acc) ->
    mqtt_opts(Opts, [{proto_ver, v3}|Acc]);
mqtt_opts([{version, 4}|Opts], Acc) ->
    mqtt_opts(Opts, [{proto_ver, v4}|Acc]);
mqtt_opts([{version, 5}|Opts], Acc) ->
    mqtt_opts(Opts, [{proto_ver, v5}|Acc]);
mqtt_opts([{username, Username}|Opts], Acc) ->
    mqtt_opts(Opts, [{username, list_to_binary(Username)}|Acc]);
mqtt_opts([{password, Password}|Opts], Acc) ->
    mqtt_opts(Opts, [{password, list_to_binary(Password)}|Acc]);
mqtt_opts([{keepalive, I}|Opts], Acc) ->
    mqtt_opts(Opts, [{keepalive, I}|Acc]);
mqtt_opts([{clean, Bool}|Opts], Acc) ->
    mqtt_opts(Opts, [{clean_start, Bool}|Acc]);
mqtt_opts([ssl|Opts], Acc) ->
    mqtt_opts(Opts, [{ssl, true}|Acc]);
mqtt_opts([{ssl, Bool}|Opts], Acc) ->
    mqtt_opts(Opts, [{ssl, Bool}|Acc]);
mqtt_opts([{lowmem, Bool}|Opts], Acc) ->
    mqtt_opts(Opts, [{low_mem, Bool} | Acc]);
mqtt_opts([_|Opts], Acc) ->
    mqtt_opts(Opts, Acc).


interpolate_username(Opts, N) ->
    case proplists:lookup(username, Opts) of
      none -> Opts;
      {username, Username} ->
          lists:keyreplace(username,
                            1,
                            Opts,
                            {username, interpolate_num(Username, N)})
    end.



tcp_opts(Opts) ->
    tcp_opts(Opts, []).
tcp_opts([], Acc) ->
    Acc;
tcp_opts([{lowmem, true} | Opts], Acc) ->
    tcp_opts(Opts, [{recbuf, 64} , {sndbuf, 64} | Acc]);
tcp_opts([{ifaddr, IfAddr} | Opts], Acc) ->
    {ok, IpAddr} = inet_parse:address(IfAddr),
    tcp_opts(Opts, [{ip, IpAddr}|Acc]);
tcp_opts([_|Opts], Acc) ->
    tcp_opts(Opts, Acc).

ssl_opts(Opts) ->
    ssl_opts(Opts, []).
ssl_opts([], Acc) ->
    [{ciphers, all_ssl_ciphers()} | Acc];
ssl_opts([{keyfile, KeyFile} | Opts], Acc) ->
    ssl_opts(Opts, [{keyfile, KeyFile}|Acc]);
ssl_opts([{certfile, CertFile} | Opts], Acc) ->
    ssl_opts(Opts, [{certfile, CertFile}|Acc]);
ssl_opts([_|Opts], Acc) ->
    ssl_opts(Opts, Acc).

all_ssl_ciphers() ->
    Vers = ['tlsv1', 'tlsv1.1', 'tlsv1.2', 'tlsv1.3'],
    lists:usort(lists:concat([ssl:cipher_suites(all, Ver) || Ver <- Vers])).

-spec connect_fun(proplists:proplist()) -> FunName :: atom().
connect_fun(Opts)->
    case {proplists:get_bool(ws, Opts), proplists:get_bool(quic, Opts)} of
        {true, true} ->
            throw({error, "unsupported transport: ws over quic "});
        {true, false} ->
            ws_connect;
        {false, true} ->
            quic_connect;
        {false, false} ->
            connect
    end.

client_id(PubSub, N, Opts) ->
    Prefix =
    case proplists:get_value(ifaddr, Opts) of
        undefined ->
            {ok, Host} = inet:gethostname(), Host;
        IfAddr    ->
            IfAddr
    end,
    case proplists:get_value(prefix, Opts) of
        undefined ->
            list_to_binary(lists:concat([Prefix, "_bench_", atom_to_list(PubSub),
                                    "_", N, "_", rand:uniform(16#FFFFFFFF)]));
        Val ->
            list_to_binary(lists:concat([Val, "_bench_", atom_to_list(PubSub),
                                    "_", N]))
    end.

topics_opt(Opts) ->
    Topics = topics_opt(Opts, []),
    [feed_var(bin(Topic), Opts) || Topic <- Topics].

topics_opt([], Acc) ->
    Acc;
topics_opt([{topic, Topic}|Topics], Acc) ->
    topics_opt(Topics, [Topic | Acc]);
topics_opt([_Opt|Topics], Acc) ->
    topics_opt(Topics, Acc).

topic_opt(Opts) ->
    feed_var(bin(proplists:get_value(topic, Opts)), Opts).

feed_var(Topic, Opts) when is_binary(Topic) ->
    Props = [{Var, bin(proplists:get_value(Key, Opts))} || {Key, Var} <-
                [{seq, <<"%i">>}, {client_id, <<"%c">>}, {username, <<"%u">>}]],
    lists:foldl(fun({_Var, undefined}, Acc) -> Acc;
                   ({Var, Val}, Acc) -> feed_var(Var, Val, Acc)
                end, Topic, Props).

feed_var(Var, Val, Topic) ->
    feed_var(Var, Val, words(Topic), []).
feed_var(_Var, _Val, [], Acc) ->
    join(lists:reverse(Acc));
feed_var(Var, Val, [Var|Words], Acc) ->
    feed_var(Var, Val, Words, [Val|Acc]);
feed_var(Var, Val, [W|Words], Acc) ->
    feed_var(Var, Val, Words, [W|Acc]).

words(Topic) when is_binary(Topic) ->
    [word(W) || W <- binary:split(Topic, <<"/">>, [global])].

word(<<>>)    -> '';
word(<<"+">>) -> '+';
word(<<"#">>) -> '#';
word(Bin)     -> Bin.

join([]) ->
    <<>>;
join([W]) ->
    bin(W);
join(Words) ->
    {_, Bin} =
    lists:foldr(fun(W, {true, Tail}) ->
                        {false, <<W/binary, Tail/binary>>};
                   (W, {false, Tail}) ->
                        {false, <<W/binary, "/", Tail/binary>>}
                end, {true, <<>>}, [bin(W) || W <- Words]),
    Bin.

interpolate_num(Str, N) ->
    string:replace(Str, "%i", integer_to_list(N)).

bin(A) when is_atom(A)   -> bin(atom_to_list(A));
bin(I) when is_integer(I)-> bin(integer_to_list(I));
bin(S) when is_list(S)   -> list_to_binary(S);
bin(B) when is_binary(B) -> B;
bin(undefined)           -> undefined.

replace_opts(Opts, NewOpts) ->
    lists:foldl(fun({K, _V} = This, Acc) ->
                        lists:keyreplace(K, 1, Acc, This)
                end , Opts, NewOpts).

%% trim opts to save proc stack mem.
loop_opts(Opts) ->
    lists:filter(fun({K,__V}) ->
                         lists:member(K, [payload, qos, retain, topic, lowmem, limit_fun, seq])
                 end, Opts).
