import 'package:dart_delinter/src/delinters/delint_rule.dart';

/// Removes unnecessary curly braces from interpolation expressions.
class UnnecessaryBraceInStringInterp extends DelintRule {
  /// Default constructor.
  UnnecessaryBraceInStringInterp()
      : super('unnecessary_brace_in_string_interp');

  @override
  String fix(Map error, String code) {
    if (error['code'] != name) {
      return code;
    }

    final int offset = error['location']['offset'];
    return code.replaceFirst('{', '', offset).replaceFirst('}', '', offset);
  }
}
