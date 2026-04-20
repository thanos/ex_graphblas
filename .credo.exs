%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: [
        {Credo.Check.Consistency.TabsOrSpaces},
        {Credo.Check.Consistency.SpaceInParentheses},
        {Credo.Check.Consistency.SpaceAroundOperators},
        {Credo.Check.Consistency.MultiAliasUnfold},
        {Credo.Check.Consistency.ParameterPatternMatching},
        {Credo.Check.Readability.ModuleDoc},
        {Credo.Check.Readability.FunctionNames},
        {Credo.Check.Readability.PredicateFunctionNames},
        {Credo.Check.Readability.LargeNumbers},
        {Credo.Check.Readability.SinglePipe},
        {Credo.Check.Readability.StringSigils},
        {Credo.Check.Readability.TrailingWhiteSpace},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs},
        {Credo.Check.Readability.AliasOrder},
        {Credo.Check.Readability.PreferImplicitTry},
        {Credo.Check.Readability.ModuleSpatialStructure},
        {Credo.Check.Refactor.PipeChainStart, excluded_functions: ["from_coo", "to_coo", "new", "reduce", "resolve"]},
        {Credo.Check.Refactor.CaseTrivialMatches},
        {Credo.Check.Refactor.NegatedConditionsInUnless},
        {Credo.Check.Refactor.NegatedConditions},
        {Credo.Check.Refactor.FilterFilter},
        {Credo.Check.Refactor.RejectReject},
        {Credo.Check.Refactor.MapJoin},
        {Credo.Check.Warning.IoInspect},
        {Credo.Check.Warning.IExPry},
        {Credo.Check.Warning.OperationOnSameValues},
        {Credo.Check.Warning.BoolOperationOnSameValues},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck},
        {Credo.Check.Warning.DuplicatedErlangOption},
        {Credo.Check.Warning.LazyLogging},
        {Credo.Check.Warning.UnusedEnumOperation},
        {Credo.Check.Warning.UnusedKeywordOperation},
        {Credo.Check.Warning.UnusedListOperation},
        {Credo.Check.Warning.UnusedStringOperation},
        {Credo.Check.Warning.UnusedTupleOperation},
        # Disable checks that conflict with GraphBLAS naming conventions
        {Credo.Check.Readability.Specs, false},
        {Credo.Check.Readability.MaxLineLength, max_length: 120}
      ]
    }
  ]
}