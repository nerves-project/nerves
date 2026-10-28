-module(declared_nif_module).
-export([used/0, nif/0, wrapper/1]).
-nifs([nif/0, private_nif/1]).
-on_load(init/0).

init() -> erlang:load_nif("nif", 0).

used() -> used.
wrapper(Arg) -> private_nif(Arg).
nif() -> stub().
private_nif(_Arg) -> stub().

stub() -> erlang:nif_error(not_loaded).
