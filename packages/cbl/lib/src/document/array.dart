// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:collection';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:collection/collection.dart';

import '../fleece/encoder.dart';
import '../fleece/integration/integration.dart';
import 'blob.dart';
import 'common.dart';
import 'dictionary.dart';
import 'fragment.dart';

/// Defines a set of methods for readonly accessing array data.
///
/// {@category Document}
abstract class ArrayInterface implements ArrayFragment {
  /// The number of elements in this array.
  int get length;

  /// Returns the element at the given [index].
  ///
  /// Returns `null` if the element is `null`.
  ///
  /// Throws a [RangeError] if the [index] is ouf of range.
  T? value<T extends Object>(int index);

  /// Returns the element at the given [index] as a [String].
  ///
  /// {@template cbl.ArrayInterface.typedNullableGetter}
  /// Returns `null` if the element is not a of the expected typ or it is
  /// `null`.
  ///
  /// Throws a [RangeError] if the [index] is ouf of range.
  /// {@endtemplate}
  String? string(int index);

  /// Returns the element at the given [index] as an integer number.
  ///
  /// {@template cbl.ArrayInterface.typedDefaultedGetter}
  /// Returns a default value (integer: `0`, double: `0.0`, boolean: `false`) if
  /// the element is not of the expected type or is `null`.
  ///
  /// Throws a [RangeError] if the [index] is ouf of range.
  /// {@endtemplate}
  int integer(int index);

  /// Returns the element at the given [index] as an floating point number.
  ///
  /// {@macro cbl.ArrayInterface.typedDefaultedGetter}
  double float(int index);

  /// Returns the element at the given [index] as a [num].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  num? number(int index);

  /// Returns the element at the given [index] as a [bool].
  ///
  /// {@macro cbl.ArrayInterface.typedDefaultedGetter}
  bool boolean(int index);

  /// Returns the element at the given [index] as a [Blob].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  Blob? blob(int index);

  /// Returns the element at the given [index] as a [DateTime].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  DateTime? date(int index);

  /// Returns the element at the given [index] as an [Array].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  Array? array(int index);

  /// Returns the element at the given [index] as a [Dictionary].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  Dictionary? dictionary(int index);

  /// Deeply converts this array into a representation of plain Dart objects and
  /// returns it.
  ///
  /// {@template cbl.ArrayInterface.toPrimitiveObjectConversion}
  ///
  /// ## Type conversion
  ///
  /// Values of type:
  ///
  /// - `null`, [int], [double], [bool], [String], [DateTime] and [Blob] are not
  ///   converted.
  /// - [Array] are converted to a list of type `List<Object?>` where each
  ///   element has been recursively converted.
  /// - [Dictionary]s are converted to a map of type `Map<String, Object?>`
  ///   where each value has been recursively converted.
  ///
  /// {@endtemplate}
  List<Object?> toPlainList();
}

/// Provides readonly access to array data.
///
/// {@category Document}
abstract class Array implements ArrayInterface, Iterable<Object?> {
  /// Returns a mutable copy of this array.
  MutableArray toMutable();

  /// Returns this array's data as JSON.
  String toJson();
}

/// Defines a set of methods for getting and setting array data.
///
/// {@category Document}
abstract class MutableArrayInterface
    implements ArrayInterface, MutableArrayFragment {
  // === Set ===================================================================

  /// Sets a [value] [at] the given index.
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  ///
  /// {@template cbl.MutableArrayInterface.setter}
  /// Throws a [RangeError] if the index is ouf of range.
  /// {@endtemplate}
  void setValue(Object? value, {required int at});

  /// Sets a [String] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setString(String? value, {required int at});

  /// Sets a [num] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setNumber(num? value, {required int at});

  /// Sets an integer number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setInteger(int value, {required int at});

  /// Sets a floating point number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setFloat(double value, {required int at});

  /// Sets a [bool] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  // ignore: avoid_positional_boolean_parameters
  void setBoolean(bool value, {required int at});

  /// Sets a [DateTime] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setDate(DateTime? value, {required int at});

  /// Sets a [Blob] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setBlob(Blob? value, {required int at});

  /// Sets an [Array] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setArray(Array? value, {required int at});

  /// Sets a [Dictionary] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setDictionary(Dictionary? value, {required int at});

  // === Append ================================================================

  /// Adds a [value] at the end of this array.
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  void addValue(Object? value);

  /// Adds a [String] at the end of this array.
  void addString(String? value);

  /// Adds a [num] at the end of this array.
  void addNumber(num? value);

  /// Adds a integer number at the end of this array.
  void addInteger(int value);

  /// Adds a floating point number at the end of this array.
  void addFloat(double value);

  /// Adds a [Blob] at the end of this array.
  void addBlob(Blob? value);

  /// Adds a [bool] at the end of this array.
  // ignore: avoid_positional_boolean_parameters
  void addBoolean(bool value);

  /// Adds a [DateTime] at the end of this array.
  void addDate(DateTime? value);

  /// Adds an [Array] at the end of this array.
  void addArray(Array? value);

  /// Adds a [Dictionary] at the end of this array.
  void addDictionary(Dictionary? value);

  // === Insert ================================================================

  /// Inserts a [value] [at] the given index.
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  ///
  /// {@template cbl.MutableArrayInterface.inserter}
  /// Throws a [RangeError] if the index is ouf of range.
  /// {@endtemplate}
  void insertValue(Object? value, {required int at});

  /// Inserts a [String] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertString(String? value, {required int at});

  /// Inserts a [num] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertNumber(num? value, {required int at});

  /// Inserts an integer number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertInteger(int value, {required int at});

  /// Inserts a floating point number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertFloat(double value, {required int at});

  /// Inserts a [bool] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  // ignore: avoid_positional_boolean_parameters
  void insertBoolean(bool value, {required int at});

  /// Inserts a [DateTime] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertDate(DateTime? value, {required int at});

  /// Inserts a [Blob] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertBlob(Blob? value, {required int at});

  /// Inserts an [Array] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertArray(Array? value, {required int at});

  /// Inserts a [Dictionary] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertDictionary(Dictionary? value, {required int at});

  // === Replace ===============================================================

  /// Replaces the elements of this array with those of the given [Iterable].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  void setData(Iterable<Object?> data);

  // === Remove ================================================================

  /// Removes the value at the given [index].
  void removeValue(int index);

  // === Mutable containers ====================================================

  /// Returns the element at the given [index] as a [MutableArray].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  @override
  MutableArray? array(int index);

  /// Returns the element at the given [index] as a [MutableDictionary].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  @override
  MutableDictionary? dictionary(int index);
}

/// Provides access to array data.
///
/// {@category Document}
abstract class MutableArray implements Array, MutableArrayInterface {
  /// Creates a [MutableArray], optionally initialized with [data].
  ///
  /// {@template cbl.MutableArray.allowedValueTypes}
  /// Allowed value types are [Iterable], [Array], [Blob], [DateTime],
  /// [Map<String, Object?>], [Dictionary], `null`, number types, and [String].
  ///
  /// The collections must contain only the above types.
  /// {@endtemplate}
  factory MutableArray([Iterable<Object?>? data]) {
    final array = MutableArrayImpl(MArray());
    if (data != null) {
      array.setData(data);
    }
    return array;
  }
}

class ArrayImpl
    with IterableMixin<Object?>
    implements Array, MCollectionWrapper, FleeceEncodable, CblConversions {
  ArrayImpl(this._array);

  static final _jsonEncoder = FleeceEncoder(format: FLEncoderFormat.json);

  final MArray _array;

  @override
  int get length => _array.length;

  MValue _get(int index) {
    final value = _array.get(index);
    if (value == null) {
      throw RangeError.index(index, this);
    }
    return value;
  }

  @pragma('vm:prefer-inline')
  T? _getAs<T>(int index, {bool coerceNull = false}) =>
      coerceObject(_get(index).asNative(_array), coerceNull: coerceNull);

  @pragma('vm:prefer-inline')
  T _getAsWithDefault<T>(int index, T defaultValue) =>
      _getAs(index, coerceNull: true) ?? defaultValue;

  @override
  T? value<T extends Object>(int index) => _getAs(index);

  @override
  String? string(int index) => _getAs(index);

  @override
  int integer(int index) => _getAsWithDefault(index, 0);

  @override
  double float(int index) => _getAsWithDefault(index, 0);

  @override
  num? number(int index) => _getAs(index);

  @override
  bool boolean(int index) => _getAsWithDefault(index, false);

  @override
  DateTime? date(int index) => _getAs(index);

  @override
  Blob? blob(int index) => _getAs(index);

  @override
  Array? array(int index) => _getAs(index);

  @override
  Dictionary? dictionary(int index) => _getAs(index);

  @override
  List<Object?> toPlainList({bool growable = true}) => _array.iterable
      .map((value) =>
          CblConversions.convertToPlainObject(value.asNative(_array)))
      .toList();

  @override
  Fragment operator [](int index) => FragmentImpl.fromArray(this, index: index);

  @override
  MutableArray toMutable() =>
      MutableArrayImpl(MArray.asCopy(_array, isMutable: true));

  @override
  String toJson() {
    _jsonEncoder.reset();
    encodeTo(_jsonEncoder);
    return _jsonEncoder.finish().toDartString();
  }

  @override
  MCollection get mCollection => _array;

  @override
  void encodeTo(FleeceEncoder encoder) => _array.encodeTo(encoder);

  @override
  Object? toCblObject() => toMutable();

  @override
  Object? toPlainObject() => toPlainList();

  @override
  Iterator<Object?> get iterator => Iterable.generate(length, value).iterator;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrayImpl &&
          const IterableEquality<Object?>().equals(this, other);

  @override
  int get hashCode => const IterableEquality<Object?>().hash(this);

  @override
  String toString() => toPlainList().toString();
}

class MutableArrayImpl extends ArrayImpl implements MutableArray {
  MutableArrayImpl(super.array);

  // === Set ===================================================================

  @override
  void setValue(Object? value, {required int at}) {
    // ignore: parameter_assignments
    value = CblConversions.convertToCblObject(value);
    if (valueWouldChange(value, _array.get(at), _array)) {
      if (!_array.set(at, value)) {
        throw RangeError.index(at, this, 'at');
      }
    }
  }

  @override
  void setString(String? value, {required int at}) => setValue(value, at: at);

  @override
  void setInteger(int value, {required int at}) => setValue(value, at: at);

  @override
  void setFloat(double value, {required int at}) => setValue(value, at: at);

  @override
  void setNumber(num? value, {required int at}) => setValue(value, at: at);

  @override
  void setBoolean(bool value, {required int at}) => setValue(value, at: at);

  @override
  void setDate(DateTime? value, {required int at}) => setValue(value, at: at);

  @override
  void setBlob(Blob? value, {required int at}) => setValue(value, at: at);

  @override
  void setArray(Array? value, {required int at}) => setValue(value, at: at);

  @override
  void setDictionary(Dictionary? value, {required int at}) =>
      setValue(value, at: at);

  // === Append ================================================================

  @override
  void addValue(Object? value) =>
      _array.append(CblConversions.convertToCblObject(value));

  @override
  void addString(String? value) => addValue(value);

  @override
  void addInteger(int value) => addValue(value);

  @override
  void addFloat(double value) => addValue(value);

  @override
  void addNumber(num? value) => addValue(value);

  @override
  void addBoolean(bool value) => addValue(value);

  @override
  void addDate(DateTime? value) => addValue(value);

  @override
  void addBlob(Blob? value) => addValue(value);

  @override
  void addArray(Array? value) => addValue(value);

  @override
  void addDictionary(Dictionary? value) => addValue(value);

  // === Insert ================================================================

  @override
  void insertValue(Object? value, {required int at}) {
    if (!_array.insert(at, CblConversions.convertToCblObject(value))) {
      throw RangeError.index(at, this, 'at');
    }
  }

  @override
  void insertString(String? value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertInteger(int value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertFloat(double value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertNumber(num? value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertBoolean(bool value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertDate(DateTime? value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertBlob(Blob? value, {required int at}) => insertValue(value, at: at);

  @override
  void insertArray(Array? value, {required int at}) =>
      insertValue(value, at: at);

  @override
  void insertDictionary(Dictionary? value, {required int at}) =>
      insertValue(value, at: at);

  // === Replace ===============================================================

  @override
  void setData(Iterable<Object?> data) {
    _array.clear();
    data.map(CblConversions.convertToCblObject).forEach(_array.append);
  }

  // === Remove ================================================================

  @override
  void removeValue(int index) {
    if (!_array.remove(index)) {
      throw RangeError.index(index, this);
    }
  }

  // === Mutable containers ====================================================

  @override
  MutableArray? array(int index) => super.array(index) as MutableArray?;

  @override
  MutableDictionary? dictionary(int index) =>
      super.dictionary(index) as MutableDictionary?;

  // === MutableArrayFragment ==================================================

  @override
  MutableFragment operator [](int index) =>
      MutableFragmentImpl.fromArray(this, index: index);

  // === Array =================================================================

  @override
  MutableArray toMutable() =>
      // We make a deep copy of this array, to allow the result to be used
      // with a different document and prevent modifications of this array
      // or the result affect each other.
      MutableArray(toPlainList(growable: false));

  // === CblConversions ========================================================

  @override
  Object? toCblObject() => this;
}
