import 'dart:collection';

// ignore: implementation_imports
import 'package:analyzer/src/lint/config.dart';
import 'package:dart_delinter/src/delinters/delint_rule.dart';

///Registry of delint rules.
class DelinterRegistry extends Object with IterableMixin<DelintRule> {
  ///The default registry to be used by clients.
  static final DelinterRegistry ruleRegistry = new DelinterRegistry();

  ///A table mapping rule names to rules.
  Map<String, DelintRule> _ruleMap = <String, DelintRule>{};

  @override
  Iterator<DelintRule> get iterator => _ruleMap.values.iterator;

  ///Return a list of the rules that are defined.
  Iterable<DelintRule> get rules => _ruleMap.values;

  ///Return the lint rule with the given [name].
  DelintRule operator [](String name) => _ruleMap[name];

  ///Return a list of the lint rules explicitly enabled by the given [config].
  ///
  ///For example:
  ///    my_rule: true
  ///
  ///enables `my_rule`.
  ///
  ///Unspecified rules are treated as disabled by default.
  Iterable<DelintRule> enabled(LintConfig config) => rules
      .where((rule) => config.ruleConfigs.any((rc) => rc.enables(rule.name)));

  ///Add the given lint [rule] to this registry.
  void register(DelintRule rule) {
    _ruleMap[rule.name] = rule;
  }
}
