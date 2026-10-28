-module(on_load_dependency).
-export([init/0, path/0, unused/0]).

init() -> ok.
path() -> "nif".
unused() -> unused.
