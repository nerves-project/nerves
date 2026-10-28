-module(struct_builder).
-export([build/0]).

build() ->
    {'Elixir.Kernel':'struct!'(struct_module, []), 'Elixir.Kernel':struct(other_struct_module, [])}.
