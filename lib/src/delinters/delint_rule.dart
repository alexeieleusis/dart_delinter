/// Defines contract for delinting rules.
abstract class DelintRule {
  /// The name opf the rule. Should match the name of the linter rule.
  final String name;

  /// Initializes an instance.
  DelintRule(this.name);

  /// Should perform the fix needed for the errors located during the analysis
  /// phase by mutating the AST in the right place.
  // TODO: Change map and use AnalysisError instead.
  // TODO: Change string and use CompilationUnit instead.
  String fix(Map error, String code);
}
