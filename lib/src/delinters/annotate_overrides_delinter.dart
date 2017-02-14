import 'package:dart_delinter/src/delinters/delint_rule.dart';

/// Automatically fixes occurrences of annotate_overrides
class AnnotateOverridesDelinter extends DelintRule {
  /// Initializes the rule.
  AnnotateOverridesDelinter() : super('annotate_overrides');

  @override
  String fix(Map error, String code) {
    if (error['code'] != 'annotate_overrides') {
      return code;
    }

    final Map location = error['location'];
    final int offset = location['offset'] - location['startColumn'];
    return '${code.substring(0, offset)}'
        '\n@override\n'
        '${code.substring(offset + 1)}';
  }
}
