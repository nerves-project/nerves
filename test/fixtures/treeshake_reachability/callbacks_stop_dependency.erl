-module(callbacks_stop_dependency).
-export([stop/0]).

stop() -> on_load_module:used().
