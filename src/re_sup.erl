%% -------------------------------------------------------------------
%%
%% Copyright (c) 2015 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(re_sup).
-behaviour(supervisor).
-export([start_link/1]).
-export([init/1]).


%%%===================================================================
%%% API
%%%===================================================================

start_link(StartArgs) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, StartArgs).
            
%%%===================================================================
%%% Callbacks
%%%===================================================================

init(Args) ->
    JobManager = {re_job_manager,
                  {re_job_manager, start_link, []},
                  permanent, 5000, worker, [re_job_manager]},
    Specs = case webmachine_is_running() of
        true ->
            add_wm_routes(Args),
            [JobManager];
        _ ->
            Web = {webmachine_mochiweb,
                   {webmachine_mochiweb, start, [web_config(Args)]},
                   permanent, 5000, worker, [mochiweb_socket_server]},
            [Web, JobManager]
    end,

    {ok, { {one_for_one, 10, 10}, Specs} }.

%% ====================================================================
%% Private
%% ====================================================================

add_wm_routes(Args) ->
    [webmachine_router:add_route(R) || R <- lists:reverse(re_wm:dispatch(Args))].

web_config(Args) ->
    {Ip, Port} = riak_explorer:host_port(),
    WebConfig0 = [
        {ip, Ip},
        {port, Port},
        {nodelay, true},
        {log_dir, "log"},
        {dispatch, re_wm:dispatch(Args)}
    ],
    WebConfig1 = case application:get_env(riak_explorer, ssl) of
        {ok, SSLOpts} ->
            WebConfig0 ++ [{ssl, true}, {ssl_opts, SSLOpts}];
        undefined ->
            WebConfig0
    end,
    WebConfig1.

-spec webmachine_is_running() -> boolean().
webmachine_is_running() ->
    try
        case mochiweb_socket_server:get(webmachine_mochiweb, port) of
            P when is_integer(P) -> true;
            _ -> false
        end
    catch
        _:_ ->
            riak_explorer:is_riak()
    end.
