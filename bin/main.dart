import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/src/lint/config.dart';
import 'package:analyzer/src/lint/linter.dart';
import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer/src/lint/io.dart' as analyzer_io;
import 'package:args/args.dart';
import 'package:analysis_client/analysis_client.dart';
import 'package:dart_delinter/src/delinters/annotate_overrides_delinter.dart';
import 'package:dart_delinter/src/delinters/await_only_futures_delinter.dart';
import 'package:dart_delinter/src/delinters/delint_rule.dart';
import 'package:dart_delinter/src/delinters/type_init_formals_delinter.dart';
import 'package:dart_delinter/src/delinters/unnecessary_brace_in_string_interp_delinter.dart';
import 'package:dart_delinter/src/logging.dart';

AnalysisServer analysisServer;

void main(List<String> args) {
  print(args);
  _runDelinter(args, new LinterOptions(), new Logger());
}

const _processFileFailedExitCode = 65;

const _unableToProcessExitCode = 64;

JsonDecoder _decoder = new JsonDecoder();

List<DelintRule> _rules = [
  new AnnotateOverridesDelinter(),
  new AwaitOnlyFuturesDelinter(),
  new UnnecessaryBraceInStringInterp(),
  new TypeInitFormals(),
];

Map<String, File> _buildFiles(List<String> paths) {
  final files = <String, File>{};
  for (final path in paths) {
    files[path] = new File(path);
  }

  return files;
}

_OnData<String> _buildOnData(Process process, List<String> responses,
        List<File> filesToLint, List<Map> errors) =>
    (String line) {
      if (line == null || line.trim() == '') {
        return;
      }
      final resultMaps = line
          .split('\n')
          .map((m) => m.trim())
          .where((s) => s != null && s != '');
      for (final map in resultMaps) {
        final Map result = _decoder.convert(map);
        if (!_isLinterError(result)) {
          continue;
        }

        responses.add(map);
        errors.addAll(result['result']['errors']);

        if (responses.length == filesToLint.length) {
          _fixErrors(errors, process);
        }
      }
    };

void _fixErrors(List<Map> errors, Process process) {
  print('fixing ${errors.length} errors...');

  _sortErrors(errors);

  final List<String> paths =
      errors.map((e) => e['location']['file'].toString()).toList();

  final Map<String, File> files = _buildFiles(paths);
  final Map<String, String> sources = {};

  Future
      .wait(files.keys.map((f) => files[f].readAsString().then((code) {
            sources[f] = code;
            return code;
          })))
      .then((_) {
    for (final error in errors) {
      final path = error['location']['file'];
      final code = sources[path];
      sources[path] = _rules.fold(code, (c, r) => r.fix(error, c));
    }

    final writesFuture =
        files.keys.map((path) => files[path].writeAsString(sources[path]));
    Future.wait(writesFuture).then((_) {
      process.stdin.writeln('{"id":"stop","method":"server.shutdown"}');
    });
  });
}

bool _isLinterError(Map result) =>
    result['id'] != null &&
    result['id'] != 'start' &&
    result.containsKey('result');

void _printUsage(ArgParser parser, Logger logger, [String error]) {
  var message = "Lints Dart source files and pubspecs.";
  if (error != null) {
    message = error;
  }

  logger
    ..writeln(message)
    ..writeln('Usage: linter <file>')
    ..writeln(parser.usage)
    ..writeln('For more information, see https://github.com/dart-lang/linter');
}

Future  _runDelinter(
    List<String> args, LinterOptions initialLintOptions, Logger logger) async {

  // Force the rule registry to be populated.
  final parser = new ArgParser(allowTrailingOptions: true);

  parser
    ..addFlag("help",
        abbr: "h", negatable: false, help: "Show usage information.")
    ..addFlag('quiet', abbr: 'q', help: "Don't show individual lint errors.")
    ..addOption('config', abbr: 'c', help: 'Use configuration from this file.')
    ..addOption('dart-sdk', help: 'Custom path to a Dart SDK.')
    ..addOption('analysis-server', help: 'Path to a Dart Analysis Server.')
    ..addOption('rules',
        help: 'A list of lint rules to run. For example: '
            'avoid_as,annotate_overrides',
        allowMultiple: true)
    ..addOption('packages',
        help: 'Path to the package resolution configuration file, which\n'
            'supplies a mapping of package names to paths.  This option\n'
            'cannot be used with --package-root.')
    ..addOption('package-root',
        abbr: 'p', help: 'Custom package root. (Discouraged.)');

  ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (err) {
    _printUsage(parser, logger, err.message);
    exitCode = _unableToProcessExitCode;
    return;
  }

  if (options["help"]) {
    _printUsage(parser, logger);
    return;
  }

  if (options.rest.isEmpty) {
    _printUsage(parser, logger,
        "Please provide at least one file or directory to lint.");
    exitCode = _unableToProcessExitCode;
    return;
  }

  final lintOptions = initialLintOptions;

  final configFile = options["config"];
  if (configFile != null) {
    final config = new LintConfig.parse(analyzer_io.readFile(configFile));
    lintOptions.configure(config);
  }

  final lints = options['rules'];
  if (lints != null && !lints.isEmpty) {
    final rules = <LintRule>[];
    for (final lint in lints) {
      final rule = Registry.ruleRegistry[lint];
      if (rule == null) {
        logger.write('Unrecognized lint rule: $lint');
        exit(_unableToProcessExitCode);
      }
      rules.add(rule);
    }

    lintOptions.enabledLints = rules;
  }

  final customSdk = options['dart-sdk'];
  if (customSdk != null) {
    lintOptions.dartSdkPath = customSdk;
  }


  final String analysisServerCmd = options['analysis-server'];
  if (analysisServerCmd == null) {
    logger.write('Path to the analysis server script must be provided.');
    exit(_unableToProcessExitCode);
  }

  final customPackageRoot = options['package-root'];
  if (customPackageRoot != null) {
    lintOptions.packageRootPath = customPackageRoot;
  }

  final packageConfigFile = options['packages'];

  if (customPackageRoot != null && packageConfigFile != null) {
    logger.write("Cannot specify both '--package-root' and '--packages.");
    exitCode = _unableToProcessExitCode;
    return;
  }

  lintOptions.packageConfigPath = packageConfigFile;

  final List<File> filesToLint = [];
  for (final path in options.rest) {
    filesToLint.addAll(
        analyzer_io.collectFiles(path).where((f) => f.path.endsWith('.dart')));
  }

  try {
    final List<String> responses = [];
    var process = await Process.start('/usr/lib/google-dartlang/bin/dart', [
      analysisServerCmd,
      '--no-error-notification',
    ]);
    process.stdout
        .transform(UTF8.decoder)
        .listen(_buildOnData(process, responses, filesToLint, []));
    final analysisRoots = options.rest;

    analysisServer = new AnalysisServer(process.stdin);

    await analysisServer.analysis.setAnalysisRoots(
      'start',
      included: analysisRoots,
    );
    for (var file in filesToLint) {
      await analysisServer.analysis
          .getErrors('${filesToLint.indexOf(file)}', file.path);
      errorSink.writeln("Requsting errors for ${file.path}");
    }
  } catch (err, stack) {
    logger.writeln('''An error occurred while linting
$err
$stack''');
  }
}

void _sortErrors(List<Map> errors) {
  errors.sort((e1, e2) {
    final Map e1Location = e1['location'];
    final Map e2Location = e2['location'];
    if (e1Location['file'] == e2Location['file']) {
      return e2Location['offset'] - e1Location['offset'];
    }

    return e1Location['file']
        .toString()
        .compareTo(e2Location['file'].toString());
  });
}

typedef void _OnData<T>(T data);
