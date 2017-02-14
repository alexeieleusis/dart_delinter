import 'package:dart_delinter/src/delinters/delint_rule.dart';

/// Removes type annotations for initializing formal parameters
class TypeInitFormals extends DelintRule {
  /// Default constructor.
  TypeInitFormals() : super('type_init_formals');

  @override
  String fix(Map error, String code) {
    if (error['code'] != name) {
      return code;
    }

    final int offset = error['location']['offset'];
    final endOfType = code.indexOf('this', offset);
    return code.replaceRange(offset, endOfType, '');
  }
}
