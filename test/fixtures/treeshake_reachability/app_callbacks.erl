-module(app_callbacks).
-behaviour(application).
-export([start/2, stop/1, prep_stop/1, unused/0]).

start(_Type, _Args) ->
    struct_builder:build(),
    spawner:start(),
    options_schema:schema(),
    persistent_term:put(generated_impl, 'Elixir.GeneratedImpl'),
    persistent_term:put(schema, schema_like),
    {ok, self()}.
stop(_State) -> callbacks_stop_dependency:stop().
prep_stop(State) -> nif_module:used(), declared_nif_module:used(), State.
unused() -> unused.
