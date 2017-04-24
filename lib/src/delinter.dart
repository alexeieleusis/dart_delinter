import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dart_delinter/src/analysis_client.dart';
import 'package:dart_delinter/src/entities.dart';

String _apply(Iterable<SourceEdit> sourceEdits, String sourceCode) =>
    sourceEdits.fold(
        sourceCode,
        (code, sourceEdit) => '${code.substring(0, sourceEdit.offset)}'
            '${sourceEdit.replacement}'
            '${code.substring(sourceEdit.offset + sourceEdit.length)}');

Iterable<SourceEdit> _buildSourcesEdit(
    Iterable<GetFixesResponse> fixesResponse) {
  final sourceEdits = new LinkedHashSet<SourceEdit>();
  for (final fixes in fixesResponse) {
    for (final errorFixes in fixes.fixes) {
      for (final sourceChange in errorFixes.fixes) {
        for (final fileEdit in sourceChange.edits) {
          sourceEdits.addAll(fileEdit.edits);
        }
      }
    }
  }
  return sourceEdits.toList()..sort((e1, e2) => e2.offset - e1.offset);
}

/// A delinter can interact with the analysis server to compute and fix lints in
/// source code.
class Delinter {
  /// The directories where source code will be recursively searched.
  final Iterable<String> analysisRoots;

  /// The files to delint.
  // TODO: This could be computed from the analysis roots.
  final Iterable<File> filesToLint;

  bool _isInitialied = false;
  final AnalysisClient _analysisClient;

  /// Creates a new linter with the specified configuration.
  Delinter(String dartSdkPath, String analysisServerCmd, this.analysisRoots,
      this.filesToLint)
      : _analysisClient = new AnalysisClient(dartSdkPath, analysisServerCmd) {
    StreamSubscription<Map> subscription;
    subscription = _analysisClient.events.listen((_) async {
      _isInitialied = true;
      await subscription.cancel();
      await _analysisClient.events.first;
      await _analysisClient.setAnalysisRoots(analysisRoots);
    });
  }

  Future<Null> delint() async {
    final errors = await getErrors();

    for (final error in errors) {
      assert(error.errors
          .every((e) => e.location.file == error.errors.first.location.file));
      if (error.errors.isEmpty) {
        continue;
      }

      final filePath = error.errors.first.location.file;
      final file = new File(filePath);
      final sourceCode = await file.readAsString();
      final fixesResponse = await getFixes(error);
      final sourceEdits = _buildSourcesEdit(fixesResponse);
      await file.writeAsString(_apply(sourceEdits, sourceCode));
    }

    await _analysisClient.stop();
  }

  /// Retrieves all the errors for all the files to lint.
  Future<Iterable<GetErrorsResponse>> getErrors() async {
    await _waitInitialization();

    return await Future
        .wait(filesToLint.map((file) => _analysisClient.getErrors(file.path)));
  }

  Future<Iterable<GetFixesResponse>> getFixes(
      GetErrorsResponse errorsForFile) async {
    await _waitInitialization();

    final fixesFutures =
        errorsForFile.errors.where(isLint).map(_analysisClient.getFixes);
    return await Future.wait(fixesFutures);
  }

  Future<Null> _waitInitialization() async {
    if (_isInitialied) {
      return new Future.value(null);
    }

    await _analysisClient.events.first;
    await _analysisClient.setAnalysisRoots(analysisRoots);
    _isInitialied = true;
  }
}
