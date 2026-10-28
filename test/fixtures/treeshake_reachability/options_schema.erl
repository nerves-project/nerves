-module(options_schema).
-export([schema/0, validate/2, unused/0]).

%% Like a NimbleOptions schema, whose custom validators NimbleOptions calls
%% with the value and the arguments
schema() -> [{port, [{type, {custom, ?MODULE, validate, [port]}}]}].
validate(Value, _Key) -> {ok, Value}.
unused() -> unused.
