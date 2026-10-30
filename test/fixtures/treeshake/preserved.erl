-module(preserved).
-export([orphan/0, reaches_dependency/0]).

orphan() -> preserved.
reaches_dependency() -> shake_dependency:used().
