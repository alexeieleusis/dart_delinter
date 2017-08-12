import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_delinter/src/entities.dart';

JsonDecoder _decoder = const JsonDecoder();

bool isLint(AnalysisError error) => error.hasFix && error.type == 'LINT';

bool _isBalanced(String jsons) =>
    jsons.split('{').length == jsons.split('}').length;

typedef void _OnData<T>(T data);

/// A client for the dart analysis server.
///
/// To learn more about the analysis server api see:
/// https://htmlpreview.github.io/?https://github.com/dart-lang/sdk/blob/
/// master/pkg/analysis_server/doc/api.html
class AnalysisClient {
  Process _analysisServer;

  int _commandCounter = 0;

  final StreamController<Map> _eventsController =
      new StreamController<Map>.broadcast();

  /// Creates a client connected to a server started with the specified
  /// parameters.
  ///
  /// Before interacting with the server, it is needed to initialize the client,
  /// methods returning a future will silently do it.
  AnalysisClient(String dartSdkPath, String analysisServerPath) {
    Process.start(
        '$dartSdkPath'
        '${dartSdkPath.endsWith('/') ? '' : '/'}bin/'
        'dart',
        [
          analysisServerPath,
          '--no-error-notification',
        ]).then((process) {
      _analysisServer = process;

      process.stdout
          .transform(UTF8.decoder)
          .listen(_buildOnData(new StringBuffer()));
    });
  }

  /// Wraps all the events produced by the analysis server.
  Stream<Map> get events => _eventsController.stream;

  /// Retrieves the errors for the file specified in the path.
  Future<GetErrorsResponse> getErrors(String path) async {
    final requestId = 'error_request.${path.hashCode}.$_commandCounter';
    _analysisServer.stdin
        .writeln(new GetErrorsRequest(requestId, filePath: path));
    _commandCounter++;
    final resultMap = await events
        .firstWhere((map) => map.containsKey('id') && map['id'] == requestId);
    return new GetErrorsResponse.fromJson(resultMap);
  }

  Future<GetFixesResponse> getFixes(AnalysisError error) async {
    if (!isLint(error)) {
      throw new UnfixableErrorException(error);
    }

    final requestId = 'fix_request.${error.hashCode}.$_commandCounter';
    _commandCounter++;

    _analysisServer.stdin.writeln(new GetFixesRequest(
        requestId, error.location.file, error.location.offset));
    final resultMap = await events
        .firstWhere((map) => map.containsKey('id') && map['id'] == requestId);
    return new GetFixesResponse.fromJson(resultMap);
  }

  /// Configures the analysis roots for source code.
  Future<bool> setAnalysisRoots(
    Iterable<String> included, {
    Iterable<String> excluded: const [],
    Map<String, String> packageRoots: const {},
  }) {
    final requestId = 'setAnalysisRoots.$_commandCounter';
    _analysisServer.stdin.writeln(new SetAnalysisRootsRequest(
      requestId,
      included: included,
      excluded: excluded,
      packageRoots: packageRoots,
    ));
    _commandCounter++;
    return events
        .firstWhere((map) => map.containsKey('id') && map['id'] == requestId)
        .then((_) => true);
  }

  Future<Null> stop() async {
    final requestId = 'setAnalysisRoots.$_commandCounter';
    _commandCounter++;
    _analysisServer.stdin.writeln(new ShutdownRequest(requestId));
    await events
        .firstWhere((map) => map.containsKey('id') && map['id'] == requestId);
  }

  _OnData<String> _buildOnData(StringBuffer errorsBuffer) => (chunk) {
        if (chunk == null || chunk.trim() == '') {
          return;
        }

        errorsBuffer.write(chunk);
        final jsons = errorsBuffer.toString();
        if (!_isBalanced(jsons)) {
          return;
        }

        errorsBuffer.clear();
        final resultMaps = jsons
            .split('\n')
            .map((m) => m.trim())
            .where((s) => s != null && s != '');
        for (final map in resultMaps) {
          final Map result = _decoder.convert(map);
          _eventsController.add(result);
        }
      };
}
