import 'dart:convert';

import 'package:meta/meta.dart';

/// PODO
class AnalysisError extends Entity {
  final String severity;
  final String type;
  final Location location;
  final String message;
  final String code;
  final bool hasFix;

  ///
  AnalysisError(
      this.severity, this.type, this.location, this.message, this.code,
      {this.hasFix: false})
      : super._('analysisError');

  AnalysisError.fromJson(Map<String, dynamic> json)
      : severity = json['severity'],
        type = json['type'],
        location = new Location.fromJson(json['location']),
        message = json['message'],
        code = json['code'],
        hasFix = json['hasFix'],
        super._('analysysError');

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'severity': severity,
        'type': type,
        'location': location.toJson(),
        'message': message,
        'code': code,
        'hasFix': hasFix
      };
}

class AnalysisErrorFixes extends Entity {
  final Iterable<SourceChange> fixes;
  final AnalysisError error;

  AnalysisErrorFixes(this.fixes, this.error) : super._('AnalysisErrorFixes');

  AnalysisErrorFixes.fromJson(Map json)
      : fixes = (json['fixes'] as List<Map>)
            .map((p) => new SourceChange.fromJson(p)),
        error = new AnalysisError.fromJson(json['error']),
        super._('AnalysisErrorFixes');

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    result["error"] = error.toJson();
    result["fixes"] = fixes.map((value) => value.toJson()).toList();
    return result;
  }
}

abstract class Entity {
  final String id;

  const Entity._(this.id);

  /// Converts this entity to a JSON compatible object.
  Map<String, dynamic> toJson();

  @override
  String toString() => JSON.encode(toJson()).trim();
}

class GetErrorsRequest extends Entity {
  final String filePath;

  GetErrorsRequest(
    String id, {
    @required this.filePath,
  })
      : super._(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'method': 'analysis.getErrors',
        'params': {'file': filePath},
      };
}

class GetErrorsResponse extends Entity {
  final Iterable<AnalysisError> errors;

  GetErrorsResponse(String id, this.errors) : super._(id);

  GetErrorsResponse.fromJson(Map<String, dynamic> json)
      : errors = (json['result']['errors'] as List<Map>)
            .map((e) => new AnalysisError.fromJson(e)),
        super._(json['id']);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'result': {'errors': errors..map((e) => e.toJson())}
      };
}

class GetFixesRequest extends Entity {
  final String filePath;
  final int offset;

  GetFixesRequest(String id, this.filePath, this.offset) : super._(id);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'method': 'edit.getFixes',
        'params': {'file': filePath, 'offset': offset}
      };
}

class GetFixesResponse extends Entity {
  final Iterable<AnalysisErrorFixes> fixes;

  GetFixesResponse(String id, this.fixes) : super._(id);

  GetFixesResponse.fromJson(Map<String, dynamic> json)
      : fixes = (json['result']['fixes'] as List<Map>)
            .map((p) => new AnalysisErrorFixes.fromJson(p)),
        super._(json['id']);

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    result["fixes"] = fixes.map((value) => value.toJson()).toList();
    return {
      'id': id,
      'result': {'fixes': fixes}
    };
  }
}

class LinkedEditGroup extends Entity {
  final Iterable<Position> positions;
  final int length;
  final Iterable<LinkedEditSuggestion> suggestions;

  LinkedEditGroup(this.positions, this.length, this.suggestions)
      : super._('LinkedEditGroup');

  LinkedEditGroup.fromJson(Map<String, dynamic> json)
      : positions = (json['positions'] as List<Map>)
            .map((p) => new Position.fromJson(p)),
        length = json['length'],
        suggestions = (json['suggestions'] as List<Map>)
            .map((p) => new LinkedEditSuggestion.fromJson(p)),
        super._('LinkedEditGroup');

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    result["positions"] = positions.map((value) => value.toJson()).toList();
    result["length"] = length;
    result["suggestions"] = suggestions.map((value) => value.toJson()).toList();
    return result;
  }
}

class LinkedEditSuggestion extends Entity {
  final String value;
  final LinkedEditSuggestionKind kind;

  LinkedEditSuggestion(this.value, this.kind) : super._('LinkedEditSuggestion');

  LinkedEditSuggestion.fromJson(Map json)
      : value = json['value'],
        kind = LinkedEditSuggestionKind.values
            .firstWhere((k) => k.toString() == json['kind']),
        super._('LinkedEditSuggestion');

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {};
    result["value"] = value;
    result["kind"] = kind.toString();
    return result;
  }
}

// ignore: constant_identifier_names
enum LinkedEditSuggestionKind { METHOD, PARAMETER, TYPE, VARIABLE }

/// PODO
class Location extends Entity {
  final String file;
  final int offset;
  final int length;
  final int startLine;
  final int startColumn;

  ///
  Location(
      this.file, this.offset, this.length, this.startLine, this.startColumn)
      : super._('location');

  Location.fromJson(Map<String, dynamic> json)
      : file = json['file'],
        offset = json['offset'],
        length = json['length'],
        startLine = json['startLine'],
        startColumn = json['startColumn'],
        super._('location');

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'file': file,
        'offset': offset,
        'length': length,
        'startLine': startLine,
        'startColumn': startColumn
      };
}

class Position extends Entity {
  final String file;
  final int offset;

  Position(this.file, this.offset) : super._('Position');
  Position.fromJson(Map json)
      : file = json['file'],
        offset = json['offset'],
        super._('Position');

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {};
    result["file"] = file;
    result["offset"] = offset;
    return result;
  }
}

class SetAnalysisRootsRequest extends Entity {
  final List<String> included;
  final List<String> excluded;
  final Map<String, String> packageRoots;

  const SetAnalysisRootsRequest(
    String id, {
    this.included: const [],
    this.excluded: const [],
    this.packageRoots: const {},
  })
      : super._(id);

  @override
  Map<String, Object> toJson() => {
        'id': id,
        'method': 'analysis.setAnalysisRoots',
        'params': {
          'included': included,
          'excluded': excluded,
          'packageRoots': packageRoots,
        }
      };
}

class ShutdownRequest extends Entity {
  const ShutdownRequest(String id) : super._(id);

  @override
  Map<String, String> toJson() => <String, String>{
        'id': id,
        'method': 'server.shutdown',
      };
}

class SourceChange extends Entity {
  final String message;
  final Iterable<SourceFileEdit> edits;
  final Iterable<LinkedEditGroup> linkedEditGroups;
//  final Position selection;

  SourceChange(
      this.message, this.edits, this.linkedEditGroups /*, this.selection*/)
      : super._('SourceChange');

  SourceChange.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        edits = (json['edits'] as List<Map>)
            .map((p) => new SourceFileEdit.fromJson(p)),
        linkedEditGroups = (json['linkedEditGroups'] as List<Map>)
            .map((p) => new LinkedEditGroup.fromJson(p)),
//        selection = new Position.fromJson(json['selection']),
        super._('SourceChange');

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    result["message"] = message;
    result["edits"] = edits.map((value) => value.toJson()).toList();
    result["linkedEditGroups"] =
        linkedEditGroups.map((value) => value.toJson()).toList();
//    if (selection != null) {
//      result["selection"] = selection.toJson();
//    }
    return result;
  }
}

class SourceEdit extends Entity {
  final int offset;
  final int length;
  final String replacement;

  SourceEdit(String id, this.offset, this.length, this.replacement)
      : super._(id);

  SourceEdit.fromJson(Map<String, dynamic> json)
      : offset = json['offset'],
        length = json['length'],
        replacement = json['replacement'],
        super._(json['id']);

  @override
  int get hashCode => offset.hashCode ^ length.hashCode ^ replacement.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceEdit &&
          runtimeType == other.runtimeType &&
          offset == other.offset &&
          length == other.length &&
          replacement == other.replacement;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'offset': offset,
        'length': length,
        'replacement': replacement
      };
}

class SourceFileEdit extends Entity {
  final String file;
  final int fileStamp;
  final Iterable<SourceEdit> edits;

  SourceFileEdit(this.file, this.fileStamp, this.edits)
      : super._('SourceFileEdit');

  SourceFileEdit.fromJson(Map<String, dynamic> json)
      : file = json['file'],
        fileStamp = json['fileStamp'],
        edits = (json['edits'] as Iterable<Map>)
            .map((e) => new SourceEdit.fromJson(e)),
        super._(json['SourceFileEdit']);

  @override
  Map<String, dynamic> toJson() =>
      {'file': file, 'fileStamp': fileStamp, 'edits': edits};
}

class UnfixableErrorException implements Exception {
  final AnalysisError error;
  final String message;

  UnfixableErrorException(this.error, [String message])
      : message =
            (message ??= 'Error need to be a lint and have an automatic fix.');
}
