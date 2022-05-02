# .credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{included: ["lib/", "test/"], excluded: ["**/mix.exs"]},
      strict: true,
      checks: [
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Refactor.Apply, false},
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Warning.LazyLogging, false},
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 86400},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        {Credo.Check.Readability.Specs, tags: []},
        {Credo.Check.Readability.StrictModuleLayout, tags: []}
      ]
    }
  ]
}
