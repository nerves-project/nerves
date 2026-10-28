-module(spawner).
-export([start/0, opt_loop/0, monitor_loop/0, unused/0]).

start() ->
    spawn_opt(?MODULE, opt_loop, [], []),
    spawn_monitor(?MODULE, monitor_loop, []).
opt_loop() -> ok.
monitor_loop() -> ok.
unused() -> unused.
