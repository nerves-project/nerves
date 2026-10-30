-module(on_load_module).
-export([used/0, unused/0]).
-on_load(init/0).

init() -> on_load_dependency:init().

used() -> used.
unused() -> unused.
