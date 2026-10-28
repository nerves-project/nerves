-module(nif_module).
-export([used/0, nif_stub/0, unused/0]).
-on_load(init/0).

init() -> erlang:load_nif(on_load_dependency:path(), 0).

used() -> used.
nif_stub() -> erlang:nif_error(not_loaded).
unused() -> unused.
