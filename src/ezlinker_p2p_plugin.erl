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
	
on_message_publish(Message = #message{topic = <<"$p2p/", PeerClientId/binary>>, qos = QOS, payload = Payload}, {Filter}) ->
		with_filter(fun() ->
		  emqx_metrics:inc('ezlinker_p2p_plugin.message_publish'),
		  case  ets:lookup(emqx_channel, list_to_binary(PeerClientId)) of
			[{_, ChannelPid}] ->
				
				Message = emqx_message:make(list_to_binary(PeerClientId), QOS,  <<"$p2p/", PeerClientId/binary>>, Payload),
				ChannelPid ! {deliver, "$p2p", Message};
			[] ->
				_,
		  {ok, Message}
		end,
		  Message, <<"$p2p/", PeerClientId/binary>>, Filter).
	  
%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
parse_rule(Rules) -> parse_rule(Rules, []).

parse_rule([], Acc) -> lists:reverse(Acc);
parse_rule([{Rule, Conf} | Rules], Acc) ->
    Params = jsx:decode(iolist_to_binary(Conf)),
    Action = proplists:get_value(<<"action">>, Params),
    Filter = proplists:get_value(<<"topic">>, Params),
    parse_rule(Rules,
	       [{list_to_atom(Rule), Action, Filter} | Acc]).

with_filter(Fun, _, undefined) -> Fun(), ok;
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
	
load_(Hook, Fun, Params) ->
	case Hook of
		'message.publish'     -> emqx:hook(Hook, fun ?MODULE:Fun/2, [Params])
	end.

unload_(Hook, Fun) ->
	case Hook of
		'message.publish'     -> emqx:unhook(Hook, fun ?MODULE:Fun/2)
	end.