%%%-------------------------------------------------------------------
%% @doc ezlinker_p2p_plugin public API
%% @end
%%%-------------------------------------------------------------------

-module(ezlinker_p2p_plugin_app).

-behaviour(application).

-include("ezlinker_p2p_plugin.hrl").

-emqx_plugin(?MODULE).

-export([ start/2
        , stop/1
        ]).

start(_StartType, _StartArgs) ->
    {ok, Sup} = ezlinker_p2p_plugin_sup:start_link(),
    ?APP:load(),
    ?APP:register_metrics(),
    {ok, Sup}.

stop(_State) ->
    ?APP:unload(),
    ok.
