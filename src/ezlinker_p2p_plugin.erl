-module(ezlinker_p2p_plugin).

-include("ezlinker_p2p_plugin.hrl").

-include_lib("emqx/include/emqx.hrl").

-export([load/0, register_metrics/0, unload/0]).


-export([on_message_publish/2]).

-define(LOG(Level, Format, Args),
	emqx_logger:Level("ezlinker_p2p_plugin: " ++ Format,
			  Args)).

register_metrics() ->
    [emqx_metrics:new(MetricName)
     || MetricName
	    <- [
		'ezlinker_p2p_plugin.message_publish']].

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


%%--------------------------------------------------------------------
%% Message publish
% -record(message, {
%           id :: binary(),
%           qos = 0,
%           from :: atom() | binary(),
%           flags :: #{atom() => boolean()},
%           headers :: map(),
%           topic :: binary(),
%           payload :: binary(),
%           timestamp :: integer()
%          }).
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
						{ok, Message};
				[]-> 
					io:format("PeerClientId mappinged channel pid :~p is not exist ~n",[PeerClientId]),
			{stop, Message#message{headers = Headers#{allow_publish => false}} }
		    end
	end;
			
on_message_publish(Message = #message{topic = Topic}, {Filter}) ->
		with_filter(
		  fun() ->
			emqx_metrics:inc('advisory_plugin.message_publish'),
			%% Begin
			%% End
			{ok, Message}
		  end, Message, Topic, Filter).
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


with_filter(Fun, _, _, undefined) -> Fun();
with_filter(Fun, Msg, Topic, Filter) ->
    case emqx_topic:match(Topic, Filter) of
      true -> Fun();
      false -> {ok, Msg}
	end.
	
load_(Hook, Fun, Params) ->
	case Hook of
		'message.publish'     -> emqx:hook(Hook, fun ?MODULE:Fun/2, [Params])
	end.

unload_(Hook, Fun) ->
	case Hook of
		'message.publish'     -> emqx:unhook(Hook, fun ?MODULE:Fun/2)
	end.