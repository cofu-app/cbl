// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:collection';
import 'dart:convert';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../document.dart';
import '../document/array.dart';
import '../document/common.dart';
import '../document/dictionary.dart';
import '../fleece/containers.dart' as fl;
import '../fleece/encoder.dart';
import '../fleece/integration/integration.dart';
import '../service/cbl_service_api.dart';
import '../support/encoding.dart';
import 'result_set.dart';

/// A single row in a [ResultSet].
///
/// The name of a column is determined by the first applicable rule of the
/// following rules:
///
/// 1. The alias name of an aliased column.
/// 2. The last component of a property expression. Functions for example, are
///    **not** property expressions.
/// 3. A generated key of the format `$1`, `$2`, `$3`, ... The number after `$`
///    corresponds to the position of the column among the rest of the unnamed
///    columns and starts at `1`.
///
/// {@category Query}
abstract class Result
    implements Iterable<String>, ArrayInterface, DictionaryInterface {
  /// The number of column in this result.
  @override
  int get length;

  /// The names of the columns in this result.
  @override
  List<String> get keys;

  /// Returns the column at the given [nameOrIndex].
  ///
  /// Returns `null` if the column is `null`.
  ///
  /// Throws a [RangeError] if [nameOrIndex] is ouf of range.
  T? value<T extends Object>(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as a [String].
  ///
  /// {@template cbl.Result.typedNullableGetter}
  /// Returns `null` if the value is not a of the expected typ or it is `null`.
  ///
  /// Throws a [RangeError] if the [nameOrIndex] is ouf of range.
  /// {@endtemplate}
  String? string(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as an integer number.
  ///
  /// {@template cbl.Result.typedDefaultedGetter}
  /// Returns a default value (integer: `0`, double: `0.0`, boolean: `false`) if
  /// the column is not of the expected type or is `null`.
  ///
  /// Throws a [RangeError] if the [nameOrIndex] is ouf of range.
  /// {@endtemplate}
  int integer(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as an floating point number.
  ///
  /// {@macro cbl.Result.typedDefaultedGetter}
  double float(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as a [num].
  ///
  /// {@macro cbl.Result.typedNullableGetter}
  num? number(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as a [bool].
  ///
  /// {@macro cbl.Result.typedDefaultedGetter}
  bool boolean(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as a [DateTime].
  ///
  /// {@macro cbl.Result.typedNullableGetter}
  DateTime? date(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as a [Blob].
  ///
  /// {@macro cbl.Result.typedNullableGetter}
  Blob? blob(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as an [Array].
  ///
  /// {@macro cbl.Result.typedNullableGetter}
  Array? array(Object nameOrIndex);

  /// Returns the column at the given [nameOrIndex] as a [Dictionary].
  ///
  /// {@macro cbl.Result.typedNullableGetter}
  Dictionary? dictionary(Object nameOrIndex);

  /// Returns whether a column with the given [nameOrIndex] exists in this
  /// result.
  @override
  bool contains(Object? nameOrIndex);

  /// Returns a [Fragment] for the column at the given [nameOrIndex].
  Fragment operator [](Object nameOrIndex);

  /// Returns a JSON string which contains a dictionary of the named columns of
  /// this result.
  String toJson();
}

class ResultImpl with IterableMixin<String> implements Result {
  factory ResultImpl.fromTransferableValue(
    TransferableValue value, {
    required DatabaseMContext context,
    required List<String> columnNames,
  }) {
    final encodedData = value.encodedData;
    if (encodedData != null) {
      return ResultImpl.fromValuesData(
        encodedData.toFleece(),
        context: context,
        columnNames: columnNames,
      );
    }

    return ResultImpl.fromValuesArray(
      value.value!.asArray!,
      context: context,
      columnNames: columnNames,
    );
  }

  /// Creates a result from an array of the column values, encoded in a chunk of
  /// Fleece [data].
  ///
  /// The [context] must not be shared with other [Result]s.
  ResultImpl.fromValuesData(
    Data data, {
    required DatabaseMContext context,
    required List<String> columnNames,
  })  : _context = context,
        _columnNames = columnNames,
        columnValuesArray = null,
        columnValuesData = data;

  /// Creates a result from a fleece [array] fo the column values.
  ///
  /// The [context] can be shared with other [Result]s, if it is guaranteed that
  /// all results are from the same chunk of encoded Fleece data.
  ResultImpl.fromValuesArray(
    fl.Array array, {
    required DatabaseMContext context,
    required List<String> columnNames,
  })  : _context = context,
        _columnNames = columnNames,
        columnValuesArray = array,
        columnValuesData = null;

  static final _jsonEncoder = FleeceEncoder(format: FLEncoderFormat.json);

  final DatabaseMContext _context;
  final List<String> _columnNames;
  final Data? columnValuesData;
  final fl.Array? columnValuesArray;

  late final ArrayImpl _array = _createArray();
  late final DictionaryImpl _dictionary = _createDictionary();

  Dictionary get asDictionary => _dictionary;

  @override
  Iterator<String> get iterator => _columnNames.iterator;

  @override
  List<String> get keys => _columnNames;

  @override
  T? value<T extends Object>(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.value(nameOrIndex);
    }
    return _dictionary.value(nameOrIndex as String);
  }

  @override
  String? string(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.string(nameOrIndex);
    }
    return _dictionary.string(nameOrIndex as String);
  }

  @override
  int integer(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.integer(nameOrIndex);
    }
    return _dictionary.integer(nameOrIndex as String);
  }

  @override
  double float(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.float(nameOrIndex);
    }
    return _dictionary.float(nameOrIndex as String);
  }

  @override
  num? number(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.number(nameOrIndex);
    }
    return _dictionary.number(nameOrIndex as String);
  }

  @override
  bool boolean(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.boolean(nameOrIndex);
    }
    return _dictionary.boolean(nameOrIndex as String);
  }

  @override
  DateTime? date(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.date(nameOrIndex);
    }
    return _dictionary.date(nameOrIndex as String);
  }

  @override
  Blob? blob(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.blob(nameOrIndex);
    }
    return _dictionary.blob(nameOrIndex as String);
  }

  @override
  Array? array(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.array(nameOrIndex);
    }
    return _dictionary.array(nameOrIndex as String);
  }

  @override
  Dictionary? dictionary(Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array.dictionary(nameOrIndex);
    }
    return _dictionary.dictionary(nameOrIndex as String);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  bool contains(Object? nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return nameOrIndex >= 0 && nameOrIndex < _columnNames.length;
    }
    return _columnNames.contains(nameOrIndex);
  }

  @override
  Fragment operator [](Object nameOrIndex) {
    _checkNameOrIndex(nameOrIndex);
    if (nameOrIndex is int) {
      return _array[nameOrIndex];
    }
    return _dictionary[nameOrIndex as String];
  }

  @override
  List<Object?> toPlainList() => _array.toPlainList();

  @override
  Map<String, Object?> toPlainMap() => _dictionary.toPlainMap();

  @override
  String toJson() {
    _jsonEncoder.reset();
    _dictionary.encodeTo(_jsonEncoder);
    final sliceResult = _jsonEncoder.finish().toSliceResult();
    return utf8.decode(sliceResult.asTypedList());
  }

  EncodedData encodeColumnValues(EncodingFormat format) {
    fl.Array columnValues;

    switch (format) {
      case EncodingFormat.fleece:
        if (columnValuesData != null) {
          return EncodedData.fleece(columnValuesData!);
        } else {
          columnValues = columnValuesArray!;
        }
        break;
      case EncodingFormat.json:
        if (columnValuesData != null) {
          columnValues =
              fl.Doc.fromResultData(columnValuesData!, FLTrust.trusted).root
                  as fl.Array;
        } else {
          columnValues = columnValuesArray!;
        }
        break;
    }

    final encoder = FleeceEncoder(format: format.toFLEncoderFormat())
      ..writeValue(columnValues.pointer);
    return EncodedData(format, encoder.finish());
  }

  ArrayImpl _createArray() {
    MRoot root;
    if (columnValuesArray != null) {
      root = MRoot.fromContext(
        DatabaseMContext.from(
          _context,
          data: fl.Value.fromPointer(columnValuesArray!.pointer),
        ),
        isMutable: false,
      );
    } else {
      root = MRoot.fromContext(
        DatabaseMContext.from(
          _context,
          data: fl.Doc.fromResultData(columnValuesData!, FLTrust.trusted),
        ),
        isMutable: false,
      );
    }

    // ignore: cast_nullable_to_non_nullable
    return root.asNative as ArrayImpl;
  }

  DictionaryImpl _createDictionary() {
    final dictionary = MutableDictionary() as MutableDictionaryImpl;
    for (var i = 0; i < _columnNames.length; i++) {
      dictionary.setValue(_array.value(i), key: _columnNames[i]);
    }
    return dictionary;
  }

  void _checkNameOrIndex(Object? nameOrIndex) {
    if (!(nameOrIndex is int || nameOrIndex is String)) {
      throw ArgumentError.value(
        nameOrIndex,
        'nameOrIndex',
        'must be a String or int',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResultImpl &&
          runtimeType == other.runtimeType &&
          _dictionary == other._dictionary;

  @override
  int get hashCode => _dictionary.hashCode;

  @override
  String toString() => [
        'Result(',
        [
          for (final columnName in this)
            '$columnName: ${_dictionary.value(columnName)}'
        ].join(', '),
        ')'
      ].join();
}
