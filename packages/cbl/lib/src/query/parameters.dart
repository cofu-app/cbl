// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../document.dart';
import '../document/common.dart';
import '../document/dictionary.dart';
import '../fleece/encoder.dart';
import '../query.dart';

/// Query parameters used for setting values to the query parameters defined in
/// the query.
///
/// {@category Query}
abstract class Parameters {
  /// Creates new [Parameters], optionally initialized with parameters from a
  /// plain map.
  factory Parameters([Map<String, Object?>? parameters]) =>
      ParametersImpl(parameters);

  /// Gets the value of the parameter referenced by the given [name].
  Object? value(String name);

  /// Set a value to the query parameter referenced by the given [name].
  ///
  /// {@template cbl.Parameters.parameterDefinition}
  /// In N1QL queries, a parameter is referenced by prefixing an identifier with
  /// `$`. For example, this query defines a parameter with the name `TYPE`:
  ///
  /// ```sql
  /// SELECT * FROM _ WHERE type = $TYPE;
  /// ```
  ///
  /// When building a query through the [QueryBuilder], you can create a
  /// parameter expression with [Expression.parameter].
  /// {@endtemplate}
  void setValue(Object? value, {required String name});

  /// Set a [String] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setString(String? value, {required String name});

  /// Set an integer number to the query parameter referenced by the given
  /// [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setInteger(int? value, {required String name});

  /// Set a floating point number to the query parameter referenced by the given
  /// [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setFloat(double? value, {required String name});

  /// Set a [num] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setNumber(num? value, {required String name});

  /// Set a [bool] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  // ignore: avoid_positional_boolean_parameters
  void setBoolean(bool? value, {required String name});

  /// Set a [DateTime] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setDate(DateTime? value, {required String name});

  /// Set a [Blob] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setBlob(Blob? value, {required String name});

  /// Set an [Array] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setArray(Array? value, {required String name});

  /// Set a [Dictionary] to the query parameter referenced by the given [name].
  ///
  /// {@macro cbl.Parameters.parameterDefinition}
  void setDictionary(Dictionary? value, {required String name});
}

class ParametersImpl implements Parameters, FleeceEncodable {
  ParametersImpl([Map<String, Object?>? parameters]) : _readonly = false {
    if (parameters != null) {
      for (final entry in parameters.entries) {
        setValue(entry.value, name: entry.key);
      }
    }
  }

  ParametersImpl.from(Parameters source) : _readonly = true {
    final data = (source as ParametersImpl)._data;
    for (final key in data) {
      _data.setValue(data.value(key), key: key);
    }
  }

  final bool _readonly;
  late final _data = MutableDictionary() as MutableDictionaryImpl;

  @override
  Object? value(String name) => _data.value(name);

  @override
  void setValue(Object? value, {required String name}) {
    _checkReadonly();
    _data.setValue(value, key: name);
  }

  @override
  void setString(String? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setInteger(int? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setFloat(double? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setNumber(num? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setBoolean(bool? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setDate(DateTime? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setBlob(Blob? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setArray(Array? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void setDictionary(Dictionary? value, {required String name}) =>
      setValue(value, name: name);

  @override
  void encodeTo(FleeceEncoder encoder) => _data.encodeTo(encoder);

  void _checkReadonly() {
    if (_readonly) {
      throw StateError('These parameters are readonly.');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParametersImpl &&
          runtimeType == other.runtimeType &&
          _data == other._data;

  @override
  int get hashCode => _data.hashCode;

  @override
  String toString() => [
        'Parameters(',
        [
          for (final columnName in _data.keys)
            '\$$columnName: ${_data.value(columnName)}'
        ].join(', '),
        ')'
      ].join();
}
