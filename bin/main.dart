import 'dart:async';
import 'dart:io';

import 'package:analyzer/src/lint/config.dart';
import 'package:analyzer/src/lint/io.dart' as analyzer_io;
import 'package:analyzer/src/lint/linter.dart';
import 'package:analyzer/src/lint/registry.dart';
import 'package:args/args.dart';
import 'package:cli_util/cli_util.dart';
import 'package:dart_delinter/src/delinter.dart';
import 'package:dart_delinter/src/logging.dart';

void main(List<String> args) {
  _runDelinter(args, new LinterOptions(), new Logger());
}

const _processFileFailedExitCode = 65;

const _unableToProcessExitCode = 64;

Future _delintSourceCode(
    String dartSdkPath,
    String analysisServerCmd,
    Iterable<String> analysisRoots,
    Logger logger,
    Iterable<File> filesToLint) async {
  final delinter =
      new Delinter(dartSdkPath, analysisServerCmd, analysisRoots, filesToLint);
  await delinter.delint();
}

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

Future _runDelinter(
    List<String> args, LinterOptions initialLintOptions, Logger logger) async {
  // Force the rule registry to be populated.
  final parser = new ArgParser(allowTrailingOptions: true)
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

  final customSdk = options['dart-sdk'] ?? getSdkDir().path;
  lintOptions.dartSdkPath = customSdk;

  final String analysisServerCmd = options['analysis-server'] ??
      '$customSdk/bin/snapshots/analysis_server.dart.snapshot';

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

  final filesToLint = <File>[];
  final foldersToScan =
      options.rest.isEmpty ? [Directory.current.path] : options.rest;
  for (final path in foldersToScan) {
    final uri = new Uri.directory(path);
    final absolutePath =
        uri.isAbsolute ? uri.path : '${Directory.current.path}/${uri.path}';
    filesToLint.addAll(analyzer_io
        .collectFiles(absolutePath.replaceAll('/.', ''))
        .where((f) => f.path.endsWith('.dart')));
  }

  try {
    logger.writeln("Analyzing ${filesToLint.length} sources...");
    await _delintSourceCode(lintOptions.dartSdkPath, analysisServerCmd,
        foldersToScan, logger, filesToLint);
  } on Exception catch (err, stack) {
    logger.writeln('''An error occurred while delinting
$err
$stack''');
  }
}
