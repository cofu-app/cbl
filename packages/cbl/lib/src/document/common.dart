import 'dart:ffi';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../database.dart';
import '../database/database_base.dart';
import '../fleece/containers.dart' as fl;
import '../fleece/decoder.dart';
import '../fleece/dict_key.dart';
import '../fleece/encoder.dart';
import '../fleece/integration/integration.dart';
import '../support/ffi.dart';
import 'array.dart';
import 'blob.dart';
import 'dictionary.dart';

final _blobBindings = cblBindings.blobs.blob;
final _valueBinds = cblBindings.fleece.value;
final _decoderBinds = cblBindings.fleece.decoder;

abstract class CblConversions {
  Object? toPlainObject();
  Object? toCblObject();

  static Object? convertToPlainObject(Object? object) {
    if (object is CblConversions) {
      return object.toPlainObject();
    }
    return const _DefaultCblConversions().toPlainObject(object);
  }

  static Object? convertToCblObject(Object? object) {
    if (object is CblConversions) {
      return object.toCblObject();
    }
    return const _DefaultCblConversions().toCblObject(object);
  }
}

class _DefaultCblConversions implements CblConversions {
  const _DefaultCblConversions();

  @override
  Object? toCblObject([Object? object]) {
    // The order in which `object` is checked for the different types attempts
    // to anticipate which types of objects are used most often, to minimize
    // the number of executed checks.
    if (object is String || object is num || object is bool || object == null) {
      return object;
    }

    if (object is Map<String, Object?>) {
      if (Blob.isBlob(object)) {
        return BlobImpl.fromProperties(object);
      }
      return MutableDictionary(object);
    }

    if (object is Iterable<Object?>) {
      return MutableArray(object);
    }

    if (object is DateTime) {
      return object.toIso8601String();
    }

    if (object is Uint8List) {
      return Blob.fromData('application/octet-stream', object);
    }

    throw ArgumentError.value(
      object,
      'object',
      'cannot be stored in a Couchbase Lite Document',
    );
  }

  @override
  Object? toPlainObject([Object? object]) => object;
}

// ignore: one_member_abstracts
abstract class FleeceEncodable {
  void encodeTo(FleeceEncoder encoder);
}

class FleeceEncoderContext implements DictKeysProvider {
  FleeceEncoderContext({
    this.database,
    this.encodeQueryParameter = false,
    this.saveExternalData = false,
  });

  final DatabaseBase? database;

  final bool encodeQueryParameter;

  final bool saveExternalData;

  @override
  DictKeys? get dictKeys => database?.dictKeys;
}

abstract class MCollectionWrapper {
  MCollection get mCollection;
}

class DatabaseMContext extends MContext {
  DatabaseMContext({
    this.database,
    super.data,
    super.dictKeys,
    super.sharedKeysTable,
    super.sharedStringsTable,
  });

  DatabaseMContext.from(DatabaseMContext other, {Object? data})
      : this(
          database: other.database,
          data: data,
          dictKeys: other.dictKeys,
          sharedKeysTable: other.sharedKeysTable,
          sharedStringsTable: other.sharedStringsTable,
        );

  final DatabaseBase? database;
}

class CblMDelegate extends MDelegate {
  @override
  MCollection? collectionFromNative(Object? native) {
    if (native is MCollectionWrapper) {
      return native.mCollection;
    }
    return null;
  }

  @override
  void encodeNative(FleeceEncoder encoder, Object? native) {
    if (native == null ||
        native is String ||
        native is num ||
        native is bool ||
        native is Uint8List) {
      encoder.writeDartObject(native);
    } else if (native is DateTime) {
      encoder.writeString(native.toIso8601String());
    } else if (native is FleeceEncodable) {
      native.encodeTo(encoder);
    } else {
      throw ArgumentError.value(
        native,
        'native',
        'is not a value of a recognized native type',
      );
    }
  }

  @override
  Object? toNative(MValue value, MCollection parent, void Function() cacheIt) {
    cacheIt();

    _decoderBinds.getLoadedValue(value.value!);

    final flValue = globalLoadedFLValue.ref;
    switch (flValue.type) {
      case FLValueType.undefined:
        // `undefined` is a somewhat unusual value to be found in a Fleece
        // collection, since it is not JSON. It cannot be encoded to Fleece or
        // JSON, but is used by some APIs to signal a special condition.
        // For example, query results can contain `undefined`.
        //
        // There is no Dart representation for `undefined` in the API, yet. It
        // would be a breaking change to start returning something other than
        // `null`.
        return null;
      case FLValueType.null_:
        return null;
      case FLValueType.boolean:
        return flValue.asBool;
      case FLValueType.number:
        return flValue.isInteger ? flValue.asInt : flValue.asDouble;
      case FLValueType.string:
        return parent.context.sharedStringsTable.decode(StringSource.value);
      case FLValueType.data:
        return flValue.asData.toData()?.toTypedList();
      case FLValueType.array:
        final array = MArray.asChild(value, parent, flValue.collectionSize);
        if (parent.hasMutableChildren) {
          return MutableArrayImpl(array);
        } else {
          return ArrayImpl(array);
        }
      case FLValueType.dict:
        final flDict = Pointer<FLDict>.fromAddress(flValue.value);

        if (_blobBindings.isBlob(flDict)) {
          final context = parent.context;
          Database? database;
          if (context is DatabaseMContext) {
            database = context.database;
          }

          final dict = fl.Dict.fromPointer(
            flDict,
            // This value is alive as long as the data owner is alive and the
            // data owner does not necessarily read form a Doc (which would
            // allow Fleece values to be retained).
            isRefCounted: false,
          );
          return BlobImpl.fromProperties(dict.toObject(), database: database);
        }

        final dictionary = MDict.asChild(value, parent, flValue.collectionSize);
        if (parent.hasMutableChildren) {
          return MutableDictionaryImpl(dictionary);
        } else {
          return DictionaryImpl(dictionary);
        }
    }
  }
}

bool valueWouldChange(
  Object? newValue,
  MValue? oldValue,
  MCollection container,
) {
  // If `oldValue` is null it was undefined.
  if (oldValue == null) {
    return true;
  }

  // Collection values are assumed to result in a change to skip expensive
  // comparisons of large instances.
  final flValue = oldValue.value;
  if (flValue != null) {
    final valueType = _valueBinds.getType(flValue);
    cblReachabilityFence(container.context);
    if (valueType == FLValueType.array || valueType == FLValueType.dict) {
      return true;
    }
  }
  if (newValue is Array || newValue is Dictionary) {
    return true;
  }

  return newValue != oldValue.asNative(container);
}

@pragma('vm:prefer-inline')
T? coerceObject<T>(Object? object, {required bool coerceNull}) {
  if (!coerceNull && object == null) {
    return null;
  }
  if (object is T) {
    return object;
  }
  if (T == bool) {
    if (object == null) {
      return false as T;
    }
    if (object is num) {
      return (object.toInt() != 0) as T;
    }
    return true as T;
  }
  if (T == int) {
    if (object is num) {
      return object.toInt() as T;
    }
  }
  if (T == double) {
    if (object is num) {
      return object.toDouble() as T;
    }
  }
  if (T == DateTime) {
    if (object is String) {
      return DateTime.parse(object) as T;
    }
  }
  return null;
}
