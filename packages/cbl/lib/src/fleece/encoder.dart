import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../support/errors.dart';
import '../support/ffi.dart';
import 'containers.dart';

final _encoderBinds = cblBindings.fleece.encoder;

/// An encoder, which generates encoded Fleece or JSON data.
///
/// It's sort of a structured output stream, with nesting. There are functions
/// for writing every type of scalar value, and for beginning and ending
/// collections. To write a collection you begin it, write its values, then end
/// it. (Of course a value in a collection can itself be another collection.)
/// When writing a dictionary, you have to call writeKey before writing each
/// value.
class FleeceEncoder implements Finalizable {
  /// Creates an encoder, which generates encoded Fleece or JSON data.
  FleeceEncoder({
    this.format = FLEncoderFormat.fleece,
    this.reserveSize = 256,
    this.uniqueStrings = true,
  }) : _pointer = _encoderBinds.create(
          format: format,
          reserveSize: reserveSize,
          uniqueStrings: uniqueStrings,
        ) {
    _encoderBinds.bindToDartObject(this, _pointer);
  }

  final Pointer<FLEncoder> _pointer;

  /// The output format to generate.
  ///
  /// The default is [FLEncoderFormat.fleece]
  final FLEncoderFormat format;

  /// The number of bytes to preallocate for the output.
  ///
  /// The default is 256.
  final int reserveSize;

  /// If true, string values that appear multiple times will be written as a
  /// single shared value. (Fleece only)
  ///
  /// This saves space but makes encoding slightly slower. You should only turn
  /// this off if you know you're going to be writing large numbers of
  /// non-repeated strings.
  ///
  /// The default is `true`.
  final bool uniqueStrings;

  /// Tells the encoder to use a shared-keys mapping when encoding dictionary
  /// keys.
  void setSharedKeys(SharedKeys? sharedKeys) {
    try {
      _encoderBinds.setSharedKeys(_pointer, sharedKeys?.pointer ?? nullptr);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Arbitrary information which needs to be available to code that is using
  /// this encoder.
  ///
  /// This is useful, for example, if an encoder is passed through an object
  /// hierarchies to let objects encode them self.
  Object? extraInfo;

  /// Converts the [json] string to [format] and returns the result.
  Data convertJson(String json) {
    reset();
    // TODO(blaugold): Remove ignore when Dart 3.2 is a minimum requirement.
    // ignore: unnecessary_cast
    writeJson(Data.fromTypedList(utf8.encode(json) as Uint8List));
    return finish();
  }

  /// Writes a Dart object to this encoder.
  ///
  /// [value] must be `null` or of type [bool], [int], [double], [String],
  /// [TypedData], [Iterable] or [Map]. The values of an [Iterable] or [Map]
  /// must satisfy this requirement as well. The keys of a [Map] must be
  /// [String]s.
  void writeDartObject(Object? value) {
    if (value == null) {
      writeNull();
    } else if (value is bool) {
      writeBool(value);
    } else if (value is int) {
      writeInt(value);
    } else if (value is double) {
      writeDouble(value);
    } else if (value is String) {
      writeString(value);
    } else if (value is Uint8List) {
      writeData(value.toData());
    } else if (value is Iterable) {
      final list = value.toList();
      beginArray(list.length);
      list.forEach(writeDartObject);
      endArray();
    } else if (value is Map) {
      beginDict(value.length);
      for (final entry in value.entries) {
        writeKey(entry.key as String);
        writeDartObject(entry.value);
      }
      endDict();
    } else {
      throw ArgumentError.value(
        value,
        'value',
        'is not of a type which can be encoded by the FleeceEncoder',
      );
    }
  }

  /// Writes the value at [index] in [array] to this encoder.
  void writeArrayValue(Pointer<FLArray> array, int index) {
    try {
      _encoderBinds.writeArrayValue(_pointer, array, index);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes [value] this encoder.
  void writeValue(Pointer<FLValue> value) {
    try {
      _encoderBinds.writeValue(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes `null` to this encoder.
  void writeNull() {
    try {
      _encoderBinds.writeNull(_pointer);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes the [bool] [value] to this encoder.
  // ignore: avoid_positional_boolean_parameters
  void writeBool(bool value) {
    try {
      _encoderBinds.writeBool(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes the [int] [value] to this encoder.
  void writeInt(int value) {
    try {
      _encoderBinds.writeInt(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes the [double] [value] to this encoder.
  void writeDouble(double value) {
    try {
      _encoderBinds.writeDouble(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes the [String] [value] to this encoder.
  void writeString(String value) {
    try {
      _encoderBinds.writeString(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes the [TypedData] [value] to this encoder.
  void writeData(Data value) {
    try {
      _encoderBinds.writeData(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes the UTF-8 encoded JSON string [value] to this encoder.
  void writeJson(Data value) {
    try {
      _encoderBinds.writeJSON(_pointer, value);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Begins an array and reserves space for [reserveLength] element.
  void beginArray(int reserveLength) {
    try {
      _encoderBinds.beginArray(_pointer, reserveLength);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Ends an array.
  void endArray() {
    try {
      _encoderBinds.endArray(_pointer);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Begins a dict and reserves space for [reserveLength] entries.
  void beginDict(int reserveLength) {
    try {
      _encoderBinds.beginDict(_pointer, reserveLength);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes a [key] for the next entry in a dict.
  void writeKey(String key) {
    try {
      _encoderBinds.writeKey(_pointer, key);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes a [key] for the next entry in a dict, from a [FLString].
  void writeKeyFLString(FLString key) {
    try {
      _encoderBinds.writeKeyFLString(_pointer, key);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Writes a [key] for the next entry in a dict, from a [FLValue].
  void writeKeyValue(Pointer<FLValue> key) {
    try {
      _encoderBinds.writeKeyValue(_pointer, key);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Ends a dict.
  void endDict() {
    try {
      _encoderBinds.endDict(_pointer);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Resets this encoder and allows it to be used again.
  void reset() {
    try {
      _encoderBinds.reset(_pointer);
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }

  /// Finishes encoding and returns the result.
  ///
  /// To begin a new piece of Fleece data call [reset].
  Data finish() {
    try {
      final result = _encoderBinds.finish(_pointer);
      if (result == null) {
        throw StateError('Encoder did not encode anything.');
      }
      return result;
    } on CBLErrorException catch (e) {
      throw toCouchbaseLiteException(e);
    }
  }
}
