import 'package:analyzer/src/lint/io.dart';

/// A simple logging interface.
abstract class Logger {
  /// Creates a [Logger] using the default input/output sinks for logging.
  factory Logger() => new _SinkLogger(outSink, errorSink);

  /// Creates a [Logger] that writes messages to [std] and errors to [err].
  factory Logger.fromSinks({StringSink std, StringSink err}) =>
      new _SinkLogger(std, err);

  /// Writes [message] to output.
  void write(String message);

  /// Writes [message] followed by a newline to output.
  void writeln(String message);

  /// Writes [message] to output as an error.
  void error(String message);
}

/// A [Logger] implementation that writes to the specified [StringSink]s.
class _SinkLogger implements Logger {
  final StringSink _stdout;
  final StringSink _stderr;

  /// Creates a [_SinkLogger] that writes normal output to [_stdout] and errors
  /// to [_stderr].
  _SinkLogger(this._stdout, this._stderr);

  @override
  void write(String message) => _stdout.write(message);

  @override
  void writeln(String message) => _stdout.writeln(message);

  @override
  void error(String message) => _stderr.writeln(message);
}
