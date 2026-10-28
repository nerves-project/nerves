-module(other_struct_module).
-export(['__struct__'/0, '__struct__'/1]).

'__struct__'() -> #{'__struct__' => ?MODULE}.
'__struct__'(Fields) -> maps:from_list([{'__struct__', ?MODULE} | Fields]).
