-module(ezlinker_p2p_plugin).

-include("ezlinker_p2p_plugin.hrl").

-include_lib("emqx/include/emqx.hrl").

-export([load/0, register_metrics/0, unload/0]).


-export([on_message_publish/2]).
-export([on_client_subscribe/4]).

-define(LOG(Level, Format, Args),
	emqx_logger:Level("ezlinker_p2p_plugin: " ++ Format,
			  Args)).

register_metrics() ->
    [emqx_metrics:new(MetricName) || MetricName <- [
				'ezlinker_p2p_plugin.message_publish',
				'ezlinker_p2p_plugin.client_subscribe'
			]
	].

load() ->
    lists:foreach(fun ({Hook, Fun, Filter}) ->
			  load_(Hook, binary_to_atom(Fun, utf8), {Filter})
		  end,
		  parse_rule(application:get_env(?APP, hooks, []))).


unload() ->
    lists:foreach(fun ({Hook, Fun, _Filter}) ->
			  unload_(Hook, binary_to_atom(Fun, utf8))
		  end,
		  parse_rule(application:get_env(?APP, hooks, []))).
load_(Hook, Fun, Params) ->
	case Hook of
		'message.publish'  -> 
			emqx:hook(Hook, fun ?MODULE:Fun/2, [Params]);
		'client.subscribe' -> 
			emqx:hook(Hook, fun ?MODULE:Fun/4, [Params])
	end.

unload_(Hook, Fun) ->
	case Hook of
		'message.publish'  -> 
			emqx:unhook(Hook, fun ?MODULE:Fun/2);
		'client.subscribe' -> 
			emqx:hook(Hook, fun ?MODULE:Fun/4)
	end.

%%--------------------------------------------------------------------

on_message_publish(Message = #message{topic =  <<"$SYS/", _/binary>>}, _Env) ->
	{ok, Message};
%%
on_message_publish(Message = #message{headers= Headers, topic =  <<"$p2p/", Path/binary>>,qos = QOS , payload = Payload ,from = From}, _Env) ->
    case Path of 
		<<>> ->
			io:format("P2P Message is empty,will be ignored ~n"),
			{stop, Message#message{headers = Headers#{allow_publish => false}} };
		PeerClientId ->
			io:format("P2P Message:~p to ~p QOS is:~p ~n",[ Payload , PeerClientId , QOS ] ),
			case  ets:lookup(emqx_channel, PeerClientId) of

				[{_,ChannelPid}] ->
						P2PMessage = emqx_message:make( From, QOS, <<"$p2p/", PeerClientId/binary >> , Payload),
			            ChannelPid ! {deliver, <<"$p2p/", PeerClientId/binary >>, P2PMessage},
						io:format("P2PMessage is :~p ~n", [P2PMessage]),
						{ok, Message};
				[]-> 
					io:format("PeerClientId mappinged channel pid :~p is not exist ~n",[PeerClientId]),
			{stop, Message#message{headers = Headers#{allow_publish => false}} }
		    end
	end;
			
on_message_publish(Message = #message{topic = Topic}, {Filter}) ->
		with_filter(
		  fun() ->
			emqx_metrics:inc('ezlinker_p2p_plugin.message_publish'),
			%% Begin
			%% End
			{ok, Message}
		  end, Message, Topic, Filter).
%%--------------------------------------------------------------------
%% Client subscribe
%%--------------------------------------------------------------------
on_client_subscribe(#{clientid := _C, username := _U}, _Properties, RawTopicFilters, {Filter}) ->
  lists:foreach(fun({Topic, _Options}) ->
    with_filter(
      fun() ->
        emqx_metrics:inc('ezlinker_p2p_plugin.client_subscribe'),
        %% Code Start
	    io:format("Client sub topic:~p~n",[Topic]),
        %% End
        ok
      end, Topic, Filter)
                end, RawTopicFilters).

% on_client_subscribe(#{clientid := _ClientId, username := _Username}, _P, _RTF, {_F}) ->
%   lists:foreach(fun({Topic, _OP}) ->
%     with_filter(
%       fun() ->
%       emqx_metrics:inc('ezlinker_p2p_plugin.client_subscribe'),
%     %% Code Start
% 		io:format("Client sub topic:~p~n",[Topic]),
% 		case  string_start_with(Topic,"$p2p/") of
% 			false ->
% 				io:format("Client nomatch p2p topic~n"),
% 				ok;
% 			true ->
% 				io:format("Client match p2p topic ,deny~n"),
% 				{stop, deny}
% 		end
% 	%% end
%       end, Topic, _F)
% 	end, _RTF).
%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
parse_rule(Rules) -> parse_rule(Rules, []).

parse_rule([], Acc) -> lists:reverse(Acc);
parse_rule([{Rule, Conf} | Rules], Acc) ->
    Params = emqx_json:decode(iolist_to_binary(Conf)),
    Action = proplists:get_value(<<"action">>, Params),
    Filter = proplists:get_value(<<"topic">>, Params),
    parse_rule(Rules,
	       [{list_to_atom(Rule), Action, Filter} | Acc]).

with_filter(Fun, _, undefined) ->
Fun(), ok;
with_filter(Fun, Topic, Filter) ->
case emqx_topic:match(Topic, Filter) of
	true -> Fun(), ok;
	false -> ok
end.

with_filter(Fun, _, _, undefined) -> Fun();
with_filter(Fun, Msg, Topic, Filter) ->
    case emqx_topic:match(Topic, Filter) of
      true -> Fun();
      false -> {ok, Msg}
	end.
	

%% start with
string_start_with(String,SubString)->
	case  string:prefix(String,SubString) of
		nomatch ->
			false;
		_ ->
			true
	end.