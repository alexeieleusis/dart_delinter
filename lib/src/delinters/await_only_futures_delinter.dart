import 'package:dart_delinter/src/delinters/delint_rule.dart';

/// Automatically fixes occurrences of await not followed by a future.
class AwaitOnlyFuturesDelinter extends DelintRule {
  static const int _awaitLength = 6;

  /// Initializes an instance.
  AwaitOnlyFuturesDelinter() : super('await_only_futures');

  @override
  String fix(Map error, String code) {
    if (error['code'] != name) {
      return code;
    }

    final Map location = error['location'];
    final int offset = location['offset'];
    return '${code.substring(0, offset)}'
        '${code.substring(offset + _awaitLength)}';
  }
}
