// ignore: lines_longer_than_80_chars
// ignore_for_file: avoid_redundant_argument_values, avoid_positional_boolean_parameters, avoid_private_typedef_functions, camel_case_types

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'base.dart';
import 'bindings.dart';
// ignore: unused_import
import 'cblite.dart' as cblite;
// ignore: unused_import
import 'cblitedart.dart' as cblitedart;
import 'data.dart';
import 'global.dart';
import 'slice.dart';
import 'utils.dart';

const _sliceBindings = SliceBindings();

// === Common ==================================================================

enum FLCopyFlag implements Option {
  deepCopy(0),
  copyImmutables(1);

  const FLCopyFlag(this.bit);

  @override
  final int bit;
}

// === Error ===================================================================

enum FLErrorCode {
  noError,
  memoryError,
  outOfRange,
  invalidData,
  encodeError,
  jsonError,
  unknownValue,
  internalError,
  notFound,
  sharedKeysStateError,
  posixError,
  unsupported,
}

extension FLErrorCodeIntExt on int {
  FLErrorCode toFleeceErrorCode() {
    assert(this >= 0 && this <= 12);
    return FLErrorCode.values[this];
  }
}

void _checkFleeceError() {
  final code = globalFLErrorCode.value.toFleeceErrorCode();
  if (code != FLErrorCode.noError) {
    throw CBLErrorException(CBLErrorDomain.fleece, code, 'Fleece error');
  }
}

extension _FleeceErrorExt<T> on T {
  T checkFleeceError() {
    final self = this;
    if (this == nullptr || self is FLSliceResult && self.buf == nullptr) {
      _checkFleeceError();
    }
    return this;
  }
}

// === Slice ===================================================================

typedef FLSlice = cblite.FLSlice;

extension FLSliceExt on FLSlice {
  bool get isNull => buf == nullptr;

  Data? toData() => SliceResult.fromFLSlice(this)?.toData();
}

typedef FLSliceResult = cblite.FLSliceResult;

extension FLResultSliceExt on FLSliceResult {
  bool get isNull => buf == nullptr;

  Data? toData({bool retain = false}) =>
      SliceResult.fromFLSliceResult(this, retain: retain)?.toData();
}

typedef FLString = cblite.FLString;

extension FLStringExt on FLString {
  bool get isNull => buf == nullptr;

  String? toDartString() =>
      isNull ? null : buf.cast<Utf8>().toDartString(length: size);
}

typedef FLStringResult = cblite.FLStringResult;

extension FLStringResultExt on FLStringResult {
  bool get isNull => buf == nullptr;

  String? toDartStringAndRelease({bool allowMalformed = false}) {
    if (isNull) {
      return null;
    }

    final result = utf8.decode(
      buf.cast<Uint8>().asTypedList(size),
      allowMalformed: allowMalformed,
    );

    _sliceBindings.releaseSliceResultByBuf(buf);

    return result;
  }
}

final class SliceBindings {
  const SliceBindings();

  static final _sliceResultFinalizer = NativeFinalizer(Native.addressOf<
              NativeFunction<
                  cblitedart.NativeCBLDart_FLSliceResult_ReleaseByBuf>>(
          cblitedart.CBLDart_FLSliceResult_ReleaseByBuf)
      .cast());

  bool equal(FLSlice a, FLSlice b) => cblite.FLSlice_Equal(a, b);

  int compare(FLSlice a, FLSlice b) => cblite.FLSlice_Compare(a, b);

  FLSliceResult create(int size) => cblite.FLSliceResult_New(size);

  FLSliceResult copy(FLSlice slice) => cblite.FLSlice_Copy(slice);

  void bindToDartObject(
    Finalizable object, {
    required Pointer<Void> buf,
    required bool retain,
  }) {
    if (retain) {
      retainSliceResultByBuf(buf);
    }

    _sliceResultFinalizer.attach(object, buf.cast());
  }

  void retainSliceResultByBuf(Pointer<Void> buf) {
    cblitedart.CBLDart_FLSliceResult_RetainByBuf(buf);
  }

  void releaseSliceResultByBuf(Pointer<Void> buf) {
    cblitedart.CBLDart_FLSliceResult_ReleaseByBuf(buf);
  }
}

// === SharedKeys ==============================================================

typedef FLSharedKeys = cblite.FLSharedKeys;

final class SharedKeysBindings {
  const SharedKeysBindings();

  static final _finalizer = NativeFinalizer(
      Native.addressOf<NativeFunction<cblite.NativeFLSharedKeys_Release>>(
              cblite.FLSharedKeys_Release)
          .cast());

  FLSharedKeys create() => cblite.FLSharedKeys_New();

  void bindToDartObject(
    Finalizable object,
    FLSharedKeys sharedKeys, {
    required bool retain,
  }) {
    if (retain) {
      cblite.FLSharedKeys_Retain(sharedKeys);
    }

    _finalizer.attach(object, sharedKeys.cast());
  }

  int count(FLSharedKeys sharedKeys) => cblite.FLSharedKeys_Count(sharedKeys);
}

// === Slot ====================================================================

typedef FLSlot = cblite.FLSlot;

final class SlotBindings {
  const SlotBindings();

  void setNull(FLSlot slot) {
    cblite.FLSlot_SetNull(slot);
  }

  void setBool(FLSlot slot, bool value) {
    cblite.FLSlot_SetBool(slot, value);
  }

  void setInt(FLSlot slot, int value) {
    cblite.FLSlot_SetInt(slot, value);
  }

  void setDouble(FLSlot slot, double value) {
    cblite.FLSlot_SetDouble(slot, value);
  }

  void setString(FLSlot slot, String value) {
    runWithSingleFLString(value, (flValue) {
      cblite.FLSlot_SetString(slot, flValue);
    });
  }

  void setData(FLSlot slot, Data value) {
    cblite.FLSlot_SetData(slot, value.toSliceResult().makeGlobal().ref);
  }

  void setValue(FLSlot slot, FLValue value) {
    cblite.FLSlot_SetValue(slot, value);
  }
}

// === Doc =====================================================================

typedef FLDoc = cblite.FLDoc;

final class DocBindings {
  const DocBindings();

  static final _finalizer = NativeFinalizer(
      Native.addressOf<NativeFunction<cblite.NativeFLDoc_Release>>(
              cblite.FLDoc_Release)
          .cast());

  FLDoc fromResultData(
    Data data,
    FLTrust trust,
    FLSharedKeys? sharedKeys,
  ) {
    final sliceResult = data.toSliceResult();
    return cblite.FLDoc_FromResultData(
      sliceResult.makeGlobalResult().ref,
      trust.toInt(),
      sharedKeys ?? nullptr,
      nullFLSlice.ref,
    );
  }

  FLDoc fromJson(String json) => runWithSingleFLString(
        json,
        (flJson) =>
            cblite.FLDoc_FromJSON(flJson, globalFLErrorCode).checkFleeceError(),
      );

  void bindToDartObject(Finalizable object, FLDoc doc) {
    _finalizer.attach(
      object,
      doc.cast(),
      externalSize: getAllocedData(doc)?.size,
    );
  }

  SliceResult? getAllocedData(FLDoc doc) =>
      SliceResult.fromFLSliceResult(cblite.FLDoc_GetAllocedData(doc));

  FLValue getRoot(FLDoc doc) => cblite.FLDoc_GetRoot(doc);

  FLSharedKeys? getSharedKeys(FLDoc doc) =>
      cblite.FLDoc_GetSharedKeys(doc).toNullable();
}

// === Value ===================================================================

typedef FLValue = cblite.FLValue;

enum FLValueType {
  undefined,
  // ignore: constant_identifier_names
  null_,
  boolean,
  number,
  string,
  data,
  array,
  dict,
}

extension on int {
  FLValueType toFLValueType() {
    assert(this >= -1 && this <= 6);
    return FLValueType.values[this + 1];
  }
}

final class ValueBindings {
  const ValueBindings();

  static final _finalizer = NativeFinalizer(
      Native.addressOf<NativeFunction<cblite.NativeFLValue_Release>>(
              cblite.FLValue_Release)
          .cast());

  void bindToDartObject(
    Finalizable object, {
    required FLValue value,
    required bool retain,
  }) {
    if (retain) {
      this.retain(value);
    }
    _finalizer.attach(object, value.cast());
  }

  FLValue? fromData(SliceResult data, FLTrust trust) =>
      cblite.FLValue_FromData(data.makeGlobal().ref, trust.toInt())
          .toNullable();

  FLDoc? findDoc(FLValue value) => cblite.FLValue_FindDoc(value).toNullable();

  FLValueType getType(FLValue value) =>
      cblite.FLValue_GetType(value).toFLValueType();

  bool isInteger(FLValue value) => cblite.FLValue_IsInteger(value);

  bool isDouble(FLValue value) => cblite.FLValue_IsDouble(value);

  bool asBool(FLValue value) => cblite.FLValue_AsBool(value);

  int asInt(FLValue value) => cblite.FLValue_AsInt(value);

  double asDouble(FLValue value) => cblite.FLValue_AsDouble(value);

  String? asString(FLValue value) =>
      cblite.FLValue_AsString(value).toDartString();

  Data? asData(FLValue value) => cblite.FLValue_AsData(value).toData();

  String? scalarToString(FLValue value) =>
      cblite.FLValue_ToString(value).toDartStringAndRelease();

  bool isEqual(FLValue a, FLValue b) => cblite.FLValue_IsEqual(a, b);

  void retain(FLValue value) => cblite.FLValue_Retain(value);

  void release(FLValue value) => cblite.FLValue_Release(value);

  String toJSONX(
    FLValue value, {
    required bool json5,
    required bool canonical,
  }) =>
      cblite.FLValue_ToJSONX(value, json5, canonical).toDartStringAndRelease()!;
}

// === Array ===================================================================

final class FLArray extends Opaque {}

typedef _FLArray_Count_C = Uint32 Function(Pointer<FLArray> array);
typedef _FLArray_Count = int Function(Pointer<FLArray> array);

typedef _FLArray_IsEmpty_C = Bool Function(Pointer<FLArray> array);
typedef _FLArray_IsEmpty = bool Function(Pointer<FLArray> array);

typedef _FLArray_AsMutable = Pointer<FLMutableArray> Function(
  Pointer<FLArray> array,
);

typedef _FLArray_Get_C = FLValue Function(
  Pointer<FLArray> array,
  Uint32 index,
);
typedef _FLArray_Get = FLValue Function(
  Pointer<FLArray> array,
  int index,
);

final class ArrayBindings extends Bindings {
  ArrayBindings(super.parent) {
    _count = libs.cbl.lookupFunction<_FLArray_Count_C, _FLArray_Count>(
      'FLArray_Count',
      isLeaf: useIsLeaf,
    );
    _isEmpty = libs.cbl.lookupFunction<_FLArray_IsEmpty_C, _FLArray_IsEmpty>(
      'FLArray_IsEmpty',
      isLeaf: useIsLeaf,
    );
    _asMutable =
        libs.cbl.lookupFunction<_FLArray_AsMutable, _FLArray_AsMutable>(
      'FLArray_AsMutable',
      isLeaf: useIsLeaf,
    );
    _get = libs.cbl.lookupFunction<_FLArray_Get_C, _FLArray_Get>(
      'FLArray_Get',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLArray_Count _count;
  late final _FLArray_IsEmpty _isEmpty;
  late final _FLArray_AsMutable _asMutable;
  late final _FLArray_Get _get;

  int count(Pointer<FLArray> array) => _count(array);

  bool isEmpty(Pointer<FLArray> array) => _isEmpty(array);

  Pointer<FLMutableArray>? asMutable(Pointer<FLArray> array) =>
      _asMutable(array).toNullable();

  FLValue get(Pointer<FLArray> array, int index) => _get(array, index);
}

// === MutableArray ============================================================

final class FLMutableArray extends Opaque {}

typedef _FLArray_MutableCopy_C = Pointer<FLMutableArray> Function(
  Pointer<FLArray> array,
  Uint32 flags,
);
typedef _FLArray_MutableCopy = Pointer<FLMutableArray> Function(
  Pointer<FLArray> array,
  int flags,
);

typedef _FLMutableArray_New = Pointer<FLMutableArray> Function();

typedef _FLMutableArray_GetSource = Pointer<FLArray> Function(
  Pointer<FLMutableArray> array,
);

typedef _FLMutableArray_IsChanged_C = Bool Function(
  Pointer<FLMutableArray> array,
);
typedef _FLMutableArray_IsChanged = bool Function(
  Pointer<FLMutableArray> array,
);

typedef _FLMutableArray_Set_C = FLSlot Function(
  Pointer<FLMutableArray> array,
  Uint32 index,
);
typedef _FLMutableArray_Set = FLSlot Function(
  Pointer<FLMutableArray> array,
  int index,
);

typedef _FLMutableArray_Append = FLSlot Function(
  Pointer<FLMutableArray> array,
);

typedef _FLMutableArray_Insert_C = Void Function(
  Pointer<FLMutableArray> array,
  Uint32 firstIndex,
  Uint32 count,
);
typedef _FLMutableArray_Insert = void Function(
  Pointer<FLMutableArray> array,
  int firstIndex,
  int count,
);

typedef _FLMutableArray_Remove_C = Void Function(
  Pointer<FLMutableArray> array,
  Uint32 firstIndex,
  Uint32 count,
);
typedef _FLMutableArray_Remove = void Function(
  Pointer<FLMutableArray> array,
  int firstIndex,
  int count,
);

typedef _FLMutableArray_Resize_C = Void Function(
  Pointer<FLMutableArray> array,
  Uint32 size,
);
typedef _FLMutableArray_Resize = void Function(
  Pointer<FLMutableArray> array,
  int size,
);

typedef _FLMutableArray_GetMutableArray_C = Pointer<FLMutableArray> Function(
  Pointer<FLMutableArray> array,
  Uint32 index,
);
typedef _FLMutableArray_GetMutableArray = Pointer<FLMutableArray> Function(
  Pointer<FLMutableArray> array,
  int index,
);

typedef _FLMutableArray_GetMutableDict_C = Pointer<FLMutableDict> Function(
  Pointer<FLMutableArray> array,
  Uint32 index,
);
typedef _FLMutableArray_GetMutableDict = Pointer<FLMutableDict> Function(
  Pointer<FLMutableArray> array,
  int index,
);

final class MutableArrayBindings extends Bindings {
  MutableArrayBindings(super.parent) {
    _mutableCopy =
        libs.cbl.lookupFunction<_FLArray_MutableCopy_C, _FLArray_MutableCopy>(
      'FLArray_MutableCopy',
      isLeaf: useIsLeaf,
    );
    _new = libs.cbl.lookupFunction<_FLMutableArray_New, _FLMutableArray_New>(
      'FLMutableArray_New',
      isLeaf: useIsLeaf,
    );
    _getSource = libs.cbl
        .lookupFunction<_FLMutableArray_GetSource, _FLMutableArray_GetSource>(
      'FLMutableArray_GetSource',
      isLeaf: useIsLeaf,
    );
    _isChanged = libs.cbl
        .lookupFunction<_FLMutableArray_IsChanged_C, _FLMutableArray_IsChanged>(
      'FLMutableArray_IsChanged',
      isLeaf: useIsLeaf,
    );
    _set = libs.cbl.lookupFunction<_FLMutableArray_Set_C, _FLMutableArray_Set>(
      'FLMutableArray_Set',
      isLeaf: useIsLeaf,
    );
    _append =
        libs.cbl.lookupFunction<_FLMutableArray_Append, _FLMutableArray_Append>(
      'FLMutableArray_Append',
      isLeaf: useIsLeaf,
    );
    _insert = libs.cbl
        .lookupFunction<_FLMutableArray_Insert_C, _FLMutableArray_Insert>(
      'FLMutableArray_Insert',
      isLeaf: useIsLeaf,
    );
    _remove = libs.cbl
        .lookupFunction<_FLMutableArray_Remove_C, _FLMutableArray_Remove>(
      'FLMutableArray_Remove',
      isLeaf: useIsLeaf,
    );
    _resize = libs.cbl
        .lookupFunction<_FLMutableArray_Resize_C, _FLMutableArray_Resize>(
      'FLMutableArray_Resize',
      isLeaf: useIsLeaf,
    );
    _getMutableArray = libs.cbl.lookupFunction<
        _FLMutableArray_GetMutableArray_C, _FLMutableArray_GetMutableArray>(
      'FLMutableArray_GetMutableArray',
      isLeaf: useIsLeaf,
    );
    _getMutableDict = libs.cbl.lookupFunction<_FLMutableArray_GetMutableDict_C,
        _FLMutableArray_GetMutableDict>(
      'FLMutableArray_GetMutableDict',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLArray_MutableCopy _mutableCopy;
  late final _FLMutableArray_New _new;
  late final _FLMutableArray_GetSource _getSource;
  late final _FLMutableArray_IsChanged _isChanged;
  late final _FLMutableArray_Set _set;
  late final _FLMutableArray_Append _append;
  late final _FLMutableArray_Insert _insert;
  late final _FLMutableArray_Remove _remove;
  late final _FLMutableArray_Resize _resize;
  late final _FLMutableArray_GetMutableArray _getMutableArray;
  late final _FLMutableArray_GetMutableDict _getMutableDict;

  Pointer<FLMutableArray> mutableCopy(
    Pointer<FLArray> array,
    Set<FLCopyFlag> flags,
  ) =>
      _mutableCopy(array, flags.toCFlags());

  Pointer<FLMutableArray> create() => _new();

  Pointer<FLArray>? getSource(Pointer<FLMutableArray> array) =>
      _getSource(array).toNullable();

  bool isChanged(Pointer<FLMutableArray> array) => _isChanged(array);

  FLSlot set(Pointer<FLMutableArray> array, int index) => _set(array, index);

  FLSlot append(Pointer<FLMutableArray> array) => _append(array);

  void insert(Pointer<FLMutableArray> array, int index, int count) =>
      _insert(array, index, count);

  void remove(Pointer<FLMutableArray> array, int firstIndex, int count) =>
      _remove(array, firstIndex, count);

  void resize(Pointer<FLMutableArray> array, int size) => _resize(array, size);

  Pointer<FLMutableArray>? getMutableArray(
    Pointer<FLMutableArray> array,
    int index,
  ) =>
      _getMutableArray(array, index).toNullable();

  Pointer<FLMutableDict>? getMutableDict(
    Pointer<FLMutableArray> array,
    int index,
  ) =>
      _getMutableDict(array, index).toNullable();
}

// === Dict ====================================================================

final class FLDict extends Opaque {}

typedef _FLDict_Count_C = Uint32 Function(Pointer<FLDict> dict);
typedef _FLDict_Count = int Function(Pointer<FLDict> dict);

typedef _FLDict_IsEmpty_C = Bool Function(Pointer<FLDict> dict);
typedef _FLDict_IsEmpty = bool Function(Pointer<FLDict> dict);

typedef _FLDict_AsMutable = Pointer<FLMutableDict> Function(
  Pointer<FLDict> dict,
);

typedef _FLDict_Get = FLValue Function(
  Pointer<FLDict> dict,
  FLString key,
);

final class DictBindings extends Bindings {
  DictBindings(super.parent) {
    _get = libs.cbl.lookupFunction<_FLDict_Get, _FLDict_Get>(
      'FLDict_Get',
      isLeaf: useIsLeaf,
    );
    _count = libs.cbl.lookupFunction<_FLDict_Count_C, _FLDict_Count>(
      'FLDict_Count',
      isLeaf: useIsLeaf,
    );
    _isEmpty = libs.cbl.lookupFunction<_FLDict_IsEmpty_C, _FLDict_IsEmpty>(
      'FLDict_IsEmpty',
      isLeaf: useIsLeaf,
    );
    _asMutable = libs.cbl.lookupFunction<_FLDict_AsMutable, _FLDict_AsMutable>(
      'FLDict_AsMutable',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLDict_Get _get;
  late final _FLDict_Count _count;
  late final _FLDict_IsEmpty _isEmpty;
  late final _FLDict_AsMutable _asMutable;

  FLValue? get(Pointer<FLDict> dict, String key) =>
      runWithSingleFLString(key, (flKey) => _get(dict, flKey)).toNullable();

  FLValue? getWithFLString(Pointer<FLDict> dict, FLString key) =>
      _get(dict, key).toNullable();

  int count(Pointer<FLDict> dict) => _count(dict);

  bool isEmpty(Pointer<FLDict> dict) => _isEmpty(dict);

  Pointer<FLMutableDict>? asMutable(Pointer<FLDict> dict) =>
      _asMutable(dict).toNullable();
}

final class FLDictKey extends Struct {
  // ignore: unused_field
  external FLSlice _private1;
  // ignore: unused_field
  external Pointer<Void> _private2;
  @Uint32()
  // ignore: unused_field
  external int _private3;
  @Uint32()
  // ignore: unused_field
  external int _private4;
  @Bool()
  // ignore: unused_field
  external bool _private5;
}

typedef _FLDictKey_Init = FLDictKey Function(FLString key);

typedef _FLDict_GetWithKey = FLValue Function(
  Pointer<FLDict> dict,
  Pointer<FLDictKey> key,
);

final class DictKeyBindings extends Bindings {
  DictKeyBindings(super.parent) {
    _init = libs.cbl.lookupFunction<_FLDictKey_Init, _FLDictKey_Init>(
      'FLDictKey_Init',
      isLeaf: useIsLeaf,
    );
    _getWithKey =
        libs.cbl.lookupFunction<_FLDict_GetWithKey, _FLDict_GetWithKey>(
      'FLDict_GetWithKey',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLDictKey_Init _init;
  late final _FLDict_GetWithKey _getWithKey;

  void init(FLDictKey dictKey, FLString key) {
    final state = _init(key);
    dictKey
      .._private1 = state._private1
      .._private2 = state._private2
      .._private3 = state._private3
      .._private4 = state._private4
      .._private5 = state._private5;
  }

  FLValue? getWithKey(Pointer<FLDict> dict, Pointer<FLDictKey> key) =>
      _getWithKey(dict, key).toNullable();
}

// === MutableDict =============================================================

final class FLMutableDict extends Opaque {}

typedef _FLDict_MutableCopy_C = Pointer<FLMutableDict> Function(
  Pointer<FLDict> source,
  Uint32 flags,
);
typedef _FLDict_MutableCopy = Pointer<FLMutableDict> Function(
  Pointer<FLDict> source,
  int flags,
);

typedef _FLMutableDict_New = Pointer<FLMutableDict> Function();

typedef _FLMutableDict_GetSource = Pointer<FLDict> Function(
  Pointer<FLMutableDict> dict,
);

typedef _FLMutableDict_IsChanged_C = Bool Function(
  Pointer<FLMutableDict> dict,
);
typedef _FLMutableDict_IsChanged = bool Function(Pointer<FLMutableDict> dict);

typedef _FLMutableDict_Set = FLSlot Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

typedef _FLMutableDict_Remove_C = Void Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);
typedef _FLMutableDict_Remove = void Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

typedef _FLMutableDict_RemoveAll_C = Void Function(Pointer<FLMutableDict> dict);
typedef _FLMutableDict_RemoveAll = void Function(Pointer<FLMutableDict> dict);

typedef _FLMutableDict_GetMutableArray = Pointer<FLMutableArray> Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

typedef _FLMutableDict_GetMutableDict = Pointer<FLMutableDict> Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

final class MutableDictBindings extends Bindings {
  MutableDictBindings(super.parent) {
    _mutableCopy =
        libs.cbl.lookupFunction<_FLDict_MutableCopy_C, _FLDict_MutableCopy>(
      'FLDict_MutableCopy',
      isLeaf: useIsLeaf,
    );
    _new = libs.cbl.lookupFunction<_FLMutableDict_New, _FLMutableDict_New>(
      'FLMutableDict_New',
      isLeaf: useIsLeaf,
    );
    _getSource = libs.cbl
        .lookupFunction<_FLMutableDict_GetSource, _FLMutableDict_GetSource>(
      'FLMutableDict_GetSource',
      isLeaf: useIsLeaf,
    );
    _isChanged = libs.cbl
        .lookupFunction<_FLMutableDict_IsChanged_C, _FLMutableDict_IsChanged>(
      'FLMutableDict_IsChanged',
      isLeaf: useIsLeaf,
    );
    _set = libs.cbl.lookupFunction<_FLMutableDict_Set, _FLMutableDict_Set>(
      'FLMutableDict_Set',
      isLeaf: useIsLeaf,
    );
    _remove =
        libs.cbl.lookupFunction<_FLMutableDict_Remove_C, _FLMutableDict_Remove>(
      'FLMutableDict_Remove',
      isLeaf: useIsLeaf,
    );
    _removeAll = libs.cbl
        .lookupFunction<_FLMutableDict_RemoveAll_C, _FLMutableDict_RemoveAll>(
      'FLMutableDict_RemoveAll',
      isLeaf: useIsLeaf,
    );
    _getMutableArray = libs.cbl.lookupFunction<_FLMutableDict_GetMutableArray,
        _FLMutableDict_GetMutableArray>(
      'FLMutableDict_GetMutableArray',
      isLeaf: useIsLeaf,
    );
    _getMutableDict = libs.cbl.lookupFunction<_FLMutableDict_GetMutableDict,
        _FLMutableDict_GetMutableDict>(
      'FLMutableDict_GetMutableDict',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLDict_MutableCopy _mutableCopy;
  late final _FLMutableDict_New _new;
  late final _FLMutableDict_GetSource _getSource;
  late final _FLMutableDict_IsChanged _isChanged;
  late final _FLMutableDict_Set _set;
  late final _FLMutableDict_Remove _remove;
  late final _FLMutableDict_RemoveAll _removeAll;
  late final _FLMutableDict_GetMutableArray _getMutableArray;
  late final _FLMutableDict_GetMutableDict _getMutableDict;

  Pointer<FLMutableDict> mutableCopy(
    Pointer<FLDict> source,
    Set<FLCopyFlag> flags,
  ) =>
      _mutableCopy(source, flags.toCFlags());

  Pointer<FLMutableDict> create() => _new();

  Pointer<FLDict>? getSource(Pointer<FLMutableDict> dict) =>
      _getSource(dict).toNullable();

  bool isChanged(Pointer<FLMutableDict> dict) => _isChanged(dict);

  FLSlot set(Pointer<FLMutableDict> dict, String key) =>
      runWithSingleFLString(key, (flKey) => _set(dict, flKey));

  void remove(Pointer<FLMutableDict> dict, String key) {
    runWithSingleFLString(key, (flKey) => _remove(dict, flKey));
  }

  void removeAll(Pointer<FLMutableDict> dict) {
    _removeAll(dict);
  }

  Pointer<FLMutableArray>? getMutableArray(
    Pointer<FLMutableDict> array,
    String key,
  ) =>
      runWithSingleFLString(
        key,
        (flKey) => _getMutableArray(array, flKey).toNullable(),
      );

  Pointer<FLMutableDict>? getMutableDict(
    Pointer<FLMutableDict> array,
    String key,
  ) =>
      runWithSingleFLString(
        key,
        (flKey) => _getMutableDict(array, flKey).toNullable(),
      );
}

// === Decoder =================================================================

@pragma('vm:prefer-inline')
String decodeFLString(int address, int size) =>
    utf8.decode(Pointer<Uint8>.fromAddress(address).asTypedList(size));

enum FLTrust {
  untrusted,
  trusted,
}

extension on FLTrust {
  int toInt() => index;
}

final class KnownSharedKeys extends Opaque {}

typedef _CBLDart_KnownSharedKeys_New = Pointer<KnownSharedKeys> Function();

typedef _CBLDart_KnownSharedKeys_Delete_C = Void Function(
  Pointer<KnownSharedKeys> keys,
);

final class CBLDart_LoadedDictKey extends Struct {
  @Bool()
  external bool isKnownSharedKey;
  @Int()
  external int sharedKey;
  @UintPtr()
  external int stringBuf;
  @Size()
  external int stringSize;
  external FLValue value;
}

final class CBLDart_LoadedFLValue extends Struct {
  @Bool()
  external bool exists;
  @Int8()
  external int _type;
  @Bool()
  external bool isInteger;
  @Uint32()
  external int collectionSize;
  @Bool()
  external bool asBool;
  @Int64()
  external int asInt;
  @Double()
  external double asDouble;
  @UintPtr()
  external int stringBuf;
  @Size()
  external int stringSize;
  external FLSlice asData;
  @UintPtr()
  external int value;
}

// ignore: camel_case_extensions
extension CBLDart_LoadedFLValueExt on CBLDart_LoadedFLValue {
  FLValueType get type => _type.toFLValueType();
}

typedef _FLData_Dump_C = FLStringResult Function(FLSlice slice);
typedef _FLData_Dump = FLStringResult Function(FLSlice slice);

typedef _CBLDart_GetLoaded_FLValue_C = Void Function(
  FLValue value,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef _CBLDart_GetLoadedFLValue = void Function(
  FLValue value,
  Pointer<CBLDart_LoadedFLValue> out,
);

typedef _CBLDart_FLArray_GetLoaded_FLValue_C = Void Function(
  Pointer<FLArray> array,
  Uint32 index,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef _CBLDart_FLArray_GetLoadedFLValue = void Function(
  Pointer<FLArray> array,
  int index,
  Pointer<CBLDart_LoadedFLValue> out,
);

typedef _CBLDart_FLDict_GetLoaded_FLValue_C = Void Function(
  Pointer<FLDict> dict,
  FLString key,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef _CBLDart_FLDict_GetLoadedFLValue = void Function(
  Pointer<FLDict> dict,
  FLString key,
  Pointer<CBLDart_LoadedFLValue> out,
);

final class CBLDart_FLDictIterator extends Opaque {}

typedef _CBLDart_FLDictIterator_Begin_C = Pointer<CBLDart_FLDictIterator>
    Function(
  Pointer<FLDict> dict,
  Pointer<KnownSharedKeys> knownSharedKeys,
  Pointer<CBLDart_LoadedDictKey> keyOut,
  Pointer<CBLDart_LoadedFLValue> valueOut,
  Bool deleteOnDone,
  Bool preLoad,
);
typedef _CBLDart_FLDictIterator_Begin = Pointer<CBLDart_FLDictIterator>
    Function(
  Pointer<FLDict> dict,
  Pointer<KnownSharedKeys> knownSharedKeys,
  Pointer<CBLDart_LoadedDictKey> keyOut,
  Pointer<CBLDart_LoadedFLValue> valueOut,
  bool deleteOnDone,
  bool preLoad,
);

typedef _CBLDart_FLDictIterator_Delete_C = Void Function(
  Pointer<CBLDart_FLDictIterator> iterator,
);

typedef _CBLDart_FLDictIterator_Next_C = Bool Function(
  Pointer<CBLDart_FLDictIterator> iterator,
);
typedef _CBLDart_FLDictIterator_Next = bool Function(
  Pointer<CBLDart_FLDictIterator> iterator,
);

final class CBLDart_FLArrayIterator extends Opaque {}

typedef _CBLDart_FLArrayIterator_Begin_C = Pointer<CBLDart_FLArrayIterator>
    Function(
  Pointer<FLArray> array,
  Pointer<CBLDart_LoadedFLValue> valueOut,
  Bool deleteOnDone,
);
typedef _CBLDart_FLArrayIterator_Begin = Pointer<CBLDart_FLArrayIterator>
    Function(
  Pointer<FLArray> array,
  Pointer<CBLDart_LoadedFLValue> valueOut,
  bool deleteOnDone,
);

typedef _CBLDart_FLArrayIterator_Delete_C = Void Function(
  Pointer<CBLDart_FLArrayIterator> iterator,
);

typedef _CBLDart_FLArrayIterator_Next_C = Bool Function(
  Pointer<CBLDart_FLArrayIterator> iterator,
);
typedef _CBLDart_FLArrayIterator_Next = bool Function(
  Pointer<CBLDart_FLArrayIterator> iterator,
);

final class FleeceDecoderBindings extends Bindings {
  FleeceDecoderBindings(super.parent) {
    _dumpData = libs.cbl.lookupFunction<_FLData_Dump_C, _FLData_Dump>(
      'FLData_Dump',
      isLeaf: useIsLeaf,
    );
    _knownSharedKeysNew = libs.cblDart.lookupFunction<
        _CBLDart_KnownSharedKeys_New, _CBLDart_KnownSharedKeys_New>(
      'CBLDart_KnownSharedKeys_New',
    );
    _knownSharedKeysDeletePtr =
        libs.cblDart.lookup('CBLDart_KnownSharedKeys_Delete');
    _getLoadedFLValue = libs.cblDart.lookupFunction<
        _CBLDart_GetLoaded_FLValue_C, _CBLDart_GetLoadedFLValue>(
      'CBLDart_GetLoadedFLValue',
      isLeaf: useIsLeaf,
    );
    _getLoadedFLValueFromArray = libs.cblDart.lookupFunction<
        _CBLDart_FLArray_GetLoaded_FLValue_C,
        _CBLDart_FLArray_GetLoadedFLValue>(
      'CBLDart_FLArray_GetLoadedFLValue',
      isLeaf: useIsLeaf,
    );
    _getLoadedFLValueFromDict = libs.cblDart.lookupFunction<
        _CBLDart_FLDict_GetLoaded_FLValue_C, _CBLDart_FLDict_GetLoadedFLValue>(
      'CBLDart_FLDict_GetLoadedFLValue',
      isLeaf: useIsLeaf,
    );
    _dictIteratorBegin = libs.cblDart.lookupFunction<
        _CBLDart_FLDictIterator_Begin_C, _CBLDart_FLDictIterator_Begin>(
      'CBLDart_FLDictIterator_Begin',
    );
    _dictIteratorDeletePtr =
        libs.cblDart.lookup('CBLDart_FLDictIterator_Delete');
    _dictIteratorNext = libs.cblDart.lookupFunction<
        _CBLDart_FLDictIterator_Next_C, _CBLDart_FLDictIterator_Next>(
      'CBLDart_FLDictIterator_Next',
      isLeaf: useIsLeaf,
    );
    _arrayIteratorBegin = libs.cblDart.lookupFunction<
        _CBLDart_FLArrayIterator_Begin_C, _CBLDart_FLArrayIterator_Begin>(
      'CBLDart_FLArrayIterator_Begin',
    );
    _arrayIteratorDeletePtr =
        libs.cblDart.lookup('CBLDart_FLArrayIterator_Delete');
    _arrayIteratorNext = libs.cblDart.lookupFunction<
        _CBLDart_FLArrayIterator_Next_C, _CBLDart_FLArrayIterator_Next>(
      'CBLDart_FLArrayIterator_Next',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLData_Dump _dumpData;
  late final _CBLDart_KnownSharedKeys_New _knownSharedKeysNew;
  late final Pointer<NativeFunction<_CBLDart_KnownSharedKeys_Delete_C>>
      _knownSharedKeysDeletePtr;
  late final _CBLDart_GetLoadedFLValue _getLoadedFLValue;
  late final _CBLDart_FLArray_GetLoadedFLValue _getLoadedFLValueFromArray;
  late final _CBLDart_FLDict_GetLoadedFLValue _getLoadedFLValueFromDict;
  late final _CBLDart_FLDictIterator_Begin _dictIteratorBegin;
  late final Pointer<NativeFunction<_CBLDart_FLDictIterator_Delete_C>>
      _dictIteratorDeletePtr;
  late final _CBLDart_FLDictIterator_Next _dictIteratorNext;
  late final _CBLDart_FLArrayIterator_Begin _arrayIteratorBegin;
  late final Pointer<NativeFunction<_CBLDart_FLArrayIterator_Delete_C>>
      _arrayIteratorDeletePtr;
  late final _CBLDart_FLArrayIterator_Next _arrayIteratorNext;

  late final _knownSharedKeysFinalizer =
      NativeFinalizer(_knownSharedKeysDeletePtr.cast());
  late final _dictIteratorFinalizer =
      NativeFinalizer(_dictIteratorDeletePtr.cast());
  late final _arrayIteratorFinalizer =
      NativeFinalizer(_arrayIteratorDeletePtr.cast());

  String dumpData(Data data) => _dumpData(data.toSliceResult().makeGlobal().ref)
      .toDartStringAndRelease()!;

  Pointer<KnownSharedKeys> createKnownSharedKeys(Finalizable object) {
    final result = _knownSharedKeysNew();
    _knownSharedKeysFinalizer.attach(object, result.cast());
    return result;
  }

  void getLoadedValue(FLValue value) {
    _getLoadedFLValue(value, globalLoadedFLValue);
  }

  void getLoadedValueFromArray(
    Pointer<FLArray> array,
    int index,
  ) {
    _getLoadedFLValueFromArray(array, index, globalLoadedFLValue);
  }

  void getLoadedValueFromDict(
    Pointer<FLDict> array,
    String key,
  ) {
    runWithSingleFLString(key, (flKey) {
      _getLoadedFLValueFromDict(array, flKey, globalLoadedFLValue);
    });
  }

  Pointer<CBLDart_FLDictIterator> dictIteratorBegin(
    Finalizable? object,
    Pointer<FLDict> dict,
    Pointer<KnownSharedKeys> knownSharedKeys,
    Pointer<CBLDart_LoadedDictKey> keyOut,
    Pointer<CBLDart_LoadedFLValue> valueOut, {
    required bool preLoad,
  }) {
    final result = _dictIteratorBegin(
      dict,
      knownSharedKeys,
      keyOut,
      valueOut,
      object == null,
      preLoad,
    );

    if (object != null) {
      _dictIteratorFinalizer.attach(object, result.cast());
    }

    return result;
  }

  bool dictIteratorNext(Pointer<CBLDart_FLDictIterator> iterator) =>
      _dictIteratorNext(iterator);

  Pointer<CBLDart_FLArrayIterator> arrayIteratorBegin(
    Finalizable? object,
    Pointer<FLArray> array,
    Pointer<CBLDart_LoadedFLValue> valueOut,
  ) {
    final result = _arrayIteratorBegin(array, valueOut, object == null);

    if (object != null) {
      _arrayIteratorFinalizer.attach(object, result.cast());
    }

    return result;
  }

  bool arrayIteratorNext(Pointer<CBLDart_FLArrayIterator> iterator) =>
      _arrayIteratorNext(iterator);
}

// === Encoder =================================================================

enum FLEncoderFormat {
  fleece,
  json,
  json5,
}

extension on FLEncoderFormat {
  int toInt() => index;
}

final class FLEncoder extends Opaque {}

typedef _FLEncoder_NewWithOptions_C = Pointer<FLEncoder> Function(
  Uint8 format,
  Size reserveSize,
  Bool uniqueStrings,
);
typedef _FLEncoder_NewWithOptions = Pointer<FLEncoder> Function(
  int format,
  int reserveSize,
  bool uniqueStrings,
);

typedef _FLEncoder_Free_C = Void Function(Pointer<FLEncoder> encoder);

typedef _FLEncoder_SetSharedKeys_C = Void Function(
  Pointer<FLEncoder> encoder,
  FLSharedKeys sharedKeys,
);
typedef _FLEncoder_SetSharedKeys = void Function(
  Pointer<FLEncoder> encoder,
  FLSharedKeys sharedKeys,
);

typedef _FLEncoder_Reset_C = Void Function(Pointer<FLEncoder> encoder);
typedef _FLEncoder_Reset = void Function(Pointer<FLEncoder> encoder);

typedef _CBLDart_FLEncoder_WriteArrayValue_C = Bool Function(
  Pointer<FLEncoder> encoder,
  Pointer<FLArray> array,
  Uint32 index,
);
typedef _CBLDart_FLEncoder_WriteArrayValue = bool Function(
  Pointer<FLEncoder> encoder,
  Pointer<FLArray> array,
  int index,
);

typedef _FLEncoder_WriteValue_C = Bool Function(
  Pointer<FLEncoder> encoder,
  FLValue value,
);
typedef _FLEncoder_WriteValue = bool Function(
  Pointer<FLEncoder> encoder,
  FLValue value,
);

typedef _FLEncoder_WriteNull_C = Bool Function(Pointer<FLEncoder> encoder);
typedef _FLEncoder_WriteNull = bool Function(Pointer<FLEncoder> encoder);

typedef _FLEncoder_WriteBool_C = Bool Function(
  Pointer<FLEncoder> encoder,
  Bool value,
);
typedef _FLEncoder_WriteBool = bool Function(
  Pointer<FLEncoder> encoder,
  bool value,
);

typedef _FLEncoder_WriteInt_C = Bool Function(
  Pointer<FLEncoder> encoder,
  Int64 value,
);
typedef _FLEncoder_WriteInt = bool Function(
  Pointer<FLEncoder> encoder,
  int value,
);

typedef _FLEncoder_WriteDouble_C = Bool Function(
  Pointer<FLEncoder> encoder,
  Double value,
);
typedef _FLEncoder_WriteDouble = bool Function(
  Pointer<FLEncoder> encoder,
  double value,
);

typedef _FLEncoder_WriteString_C = Bool Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);
typedef _FLEncoder_WriteString = bool Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);

typedef _FLEncoder_WriteData_C = Bool Function(
  Pointer<FLEncoder> encoder,
  FLSlice value,
);
typedef _FLEncoder_WriteData = bool Function(
  Pointer<FLEncoder> encoder,
  FLSlice value,
);

typedef _FLEncoder_ConvertJSON_C = Bool Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);
typedef _FLEncoder_ConvertJSON = bool Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);

typedef _FLEncoder_BeginArray_C = Bool Function(
  Pointer<FLEncoder> encoder,
  Size reserveCount,
);
typedef _FLEncoder_BeginArray = bool Function(
  Pointer<FLEncoder> encoder,
  int reserveCount,
);

typedef _FLEncoder_EndArray_C = Bool Function(Pointer<FLEncoder> encoder);
typedef _FLEncoder_EndArray = bool Function(Pointer<FLEncoder> encoder);

typedef _FLEncoder_BeginDict_C = Bool Function(
  Pointer<FLEncoder> encoder,
  Size reserveCount,
);
typedef _FLEncoder_BeginDict = bool Function(
  Pointer<FLEncoder> encoder,
  int reserveCount,
);

typedef _FLEncoder_WriteKey_C = Bool Function(
  Pointer<FLEncoder> encoder,
  FLString key,
);
typedef _FLEncoder_WriteKey = bool Function(
  Pointer<FLEncoder> encoder,
  FLString key,
);

typedef _FLEncoder_WriteKeyValue_C = Bool Function(
  Pointer<FLEncoder> encoder,
  FLValue key,
);
typedef _FLEncoder_WriteKeyValue = bool Function(
  Pointer<FLEncoder> encoder,
  FLValue key,
);

typedef _FLEncoder_EndDict_C = Bool Function(Pointer<FLEncoder> encoder);
typedef _FLEncoder_EndDict = bool Function(Pointer<FLEncoder> encoder);

typedef _FLEncoder_Finish_C = FLSliceResult Function(
  Pointer<FLEncoder> encoder,
  Pointer<Int32> errorOut,
);
typedef _FLEncoder_Finish = FLSliceResult Function(
  Pointer<FLEncoder> encoder,
  Pointer<Int32> errorOut,
);

typedef _FLEncoder_GetError_C = Uint32 Function(Pointer<FLEncoder> encoder);
typedef _FLEncoder_GetError = int Function(Pointer<FLEncoder> encoder);

typedef _FLEncoder_GetErrorMessage_C = Pointer<Utf8> Function(
  Pointer<FLEncoder> encoder,
);
typedef _FLEncoder_GetErrorMessage = Pointer<Utf8> Function(
  Pointer<FLEncoder> encoder,
);

final class FleeceEncoderBindings extends Bindings {
  FleeceEncoderBindings(super.parent) {
    _new = libs.cbl
        .lookupFunction<_FLEncoder_NewWithOptions_C, _FLEncoder_NewWithOptions>(
      'FLEncoder_NewWithOptions',
      isLeaf: useIsLeaf,
    );
    _freePtr = libs.cbl.lookup('FLEncoder_Free');
    _setSharedKeys = libs.cbl
        .lookupFunction<_FLEncoder_SetSharedKeys_C, _FLEncoder_SetSharedKeys>(
      'FLEncoder_SetSharedKeys',
      isLeaf: useIsLeaf,
    );
    _reset = libs.cbl.lookupFunction<_FLEncoder_Reset_C, _FLEncoder_Reset>(
      'FLEncoder_Reset',
      isLeaf: useIsLeaf,
    );
    _writeArrayValue = libs.cblDart.lookupFunction<
        _CBLDart_FLEncoder_WriteArrayValue_C,
        _CBLDart_FLEncoder_WriteArrayValue>(
      'CBLDart_FLEncoder_WriteArrayValue',
      isLeaf: useIsLeaf,
    );
    _writeValue =
        libs.cbl.lookupFunction<_FLEncoder_WriteValue_C, _FLEncoder_WriteValue>(
      'FLEncoder_WriteValue',
      isLeaf: useIsLeaf,
    );
    _writeNull =
        libs.cbl.lookupFunction<_FLEncoder_WriteNull_C, _FLEncoder_WriteNull>(
      'FLEncoder_WriteNull',
      isLeaf: useIsLeaf,
    );
    _writeBool =
        libs.cbl.lookupFunction<_FLEncoder_WriteBool_C, _FLEncoder_WriteBool>(
      'FLEncoder_WriteBool',
      isLeaf: useIsLeaf,
    );
    _writeInt =
        libs.cbl.lookupFunction<_FLEncoder_WriteInt_C, _FLEncoder_WriteInt>(
      'FLEncoder_WriteInt',
      isLeaf: useIsLeaf,
    );
    _writeDouble = libs.cbl
        .lookupFunction<_FLEncoder_WriteDouble_C, _FLEncoder_WriteDouble>(
      'FLEncoder_WriteDouble',
      isLeaf: useIsLeaf,
    );
    _writeString = libs.cbl
        .lookupFunction<_FLEncoder_WriteString_C, _FLEncoder_WriteString>(
      'FLEncoder_WriteString',
      isLeaf: useIsLeaf,
    );
    _writeData =
        libs.cbl.lookupFunction<_FLEncoder_WriteData_C, _FLEncoder_WriteData>(
      'FLEncoder_WriteData',
      isLeaf: useIsLeaf,
    );
    _writeJSON = libs.cbl
        .lookupFunction<_FLEncoder_ConvertJSON_C, _FLEncoder_ConvertJSON>(
      'FLEncoder_ConvertJSON',
      isLeaf: useIsLeaf,
    );
    _beginArray =
        libs.cbl.lookupFunction<_FLEncoder_BeginArray_C, _FLEncoder_BeginArray>(
      'FLEncoder_BeginArray',
      isLeaf: useIsLeaf,
    );
    _endArray =
        libs.cbl.lookupFunction<_FLEncoder_EndArray_C, _FLEncoder_EndArray>(
      'FLEncoder_EndArray',
      isLeaf: useIsLeaf,
    );
    _beginDict =
        libs.cbl.lookupFunction<_FLEncoder_BeginDict_C, _FLEncoder_BeginDict>(
      'FLEncoder_BeginDict',
      isLeaf: useIsLeaf,
    );
    _writeKey =
        libs.cbl.lookupFunction<_FLEncoder_WriteKey_C, _FLEncoder_WriteKey>(
      'FLEncoder_WriteKey',
      isLeaf: useIsLeaf,
    );
    _writeKeyValue = libs.cbl
        .lookupFunction<_FLEncoder_WriteKeyValue_C, _FLEncoder_WriteKeyValue>(
      'FLEncoder_WriteKeyValue',
      isLeaf: useIsLeaf,
    );
    _endDict =
        libs.cbl.lookupFunction<_FLEncoder_EndDict_C, _FLEncoder_EndDict>(
      'FLEncoder_EndDict',
      isLeaf: useIsLeaf,
    );
    _finish = libs.cbl.lookupFunction<_FLEncoder_Finish_C, _FLEncoder_Finish>(
      'FLEncoder_Finish',
      isLeaf: useIsLeaf,
    );
    __getError =
        libs.cbl.lookupFunction<_FLEncoder_GetError_C, _FLEncoder_GetError>(
      'FLEncoder_GetError',
      isLeaf: useIsLeaf,
    );
    __getErrorMessage = libs.cbl.lookupFunction<_FLEncoder_GetErrorMessage_C,
        _FLEncoder_GetErrorMessage>(
      'FLEncoder_GetErrorMessage',
      isLeaf: useIsLeaf,
    );
  }

  late final _FLEncoder_NewWithOptions _new;
  late final Pointer<NativeFunction<_FLEncoder_Free_C>> _freePtr;
  late final _FLEncoder_SetSharedKeys _setSharedKeys;
  late final _FLEncoder_Reset _reset;
  late final _CBLDart_FLEncoder_WriteArrayValue _writeArrayValue;
  late final _FLEncoder_WriteValue _writeValue;
  late final _FLEncoder_WriteNull _writeNull;
  late final _FLEncoder_WriteBool _writeBool;
  late final _FLEncoder_WriteInt _writeInt;
  late final _FLEncoder_WriteDouble _writeDouble;
  late final _FLEncoder_WriteString _writeString;
  late final _FLEncoder_WriteData _writeData;
  late final _FLEncoder_ConvertJSON _writeJSON;
  late final _FLEncoder_BeginArray _beginArray;
  late final _FLEncoder_EndArray _endArray;
  late final _FLEncoder_BeginDict _beginDict;
  late final _FLEncoder_WriteKey _writeKey;
  late final _FLEncoder_WriteKeyValue _writeKeyValue;
  late final _FLEncoder_EndDict _endDict;
  late final _FLEncoder_Finish _finish;
  late final _FLEncoder_GetError __getError;
  late final _FLEncoder_GetErrorMessage __getErrorMessage;

  late final _finalizer = NativeFinalizer(_freePtr.cast());

  void bindToDartObject(Finalizable object, Pointer<FLEncoder> encoder) {
    _finalizer.attach(object, encoder.cast());
  }

  Pointer<FLEncoder> create({
    required FLEncoderFormat format,
    required int reserveSize,
    required bool uniqueStrings,
  }) =>
      _new(format.toInt(), reserveSize, uniqueStrings);

  void setSharedKeys(Pointer<FLEncoder> encoder, FLSharedKeys keys) {
    _setSharedKeys(encoder, keys);
  }

  void reset(Pointer<FLEncoder> encoder) {
    _reset(encoder);
  }

  void writeArrayValue(
    Pointer<FLEncoder> encoder,
    Pointer<FLArray> array,
    int index,
  ) {
    _checkError(encoder, _writeArrayValue(encoder, array, index));
  }

  void writeValue(Pointer<FLEncoder> encoder, FLValue value) {
    if (value == nullptr) {
      throw ArgumentError.value(value, 'value', 'must not be `nullptr`');
    }

    _checkError(encoder, _writeValue(encoder, value));
  }

  void writeNull(Pointer<FLEncoder> encoder) {
    _checkError(encoder, _writeNull(encoder));
  }

  void writeBool(Pointer<FLEncoder> encoder, bool value) {
    _checkError(encoder, _writeBool(encoder, value));
  }

  void writeInt(Pointer<FLEncoder> encoder, int value) {
    _checkError(encoder, _writeInt(encoder, value));
  }

  void writeDouble(Pointer<FLEncoder> encoder, double value) {
    _checkError(encoder, _writeDouble(encoder, value));
  }

  void writeString(Pointer<FLEncoder> encoder, String value) {
    runWithSingleFLString(value, (flValue) {
      _checkError(encoder, _writeString(encoder, flValue));
    });
  }

  void writeData(Pointer<FLEncoder> encoder, Data value) {
    final sliceResult = value.toSliceResult();
    _checkError(
      encoder,
      _writeData(encoder, sliceResult.makeGlobal().ref),
    );
  }

  void writeJSON(Pointer<FLEncoder> encoder, Data value) {
    final sliceResult = value.toSliceResult();
    _checkError(
      encoder,
      _writeJSON(
        encoder,
        sliceResult.makeGlobal().cast<FLString>().ref,
      ),
    );
  }

  void beginArray(Pointer<FLEncoder> encoder, int reserveCount) {
    _checkError(encoder, _beginArray(encoder, reserveCount));
  }

  void endArray(Pointer<FLEncoder> encoder) {
    _checkError(encoder, _endArray(encoder));
  }

  void beginDict(Pointer<FLEncoder> encoder, int reserveCount) {
    _checkError(encoder, _beginDict(encoder, reserveCount));
  }

  void writeKey(Pointer<FLEncoder> encoder, String key) {
    runWithSingleFLString(key, (flKey) {
      _checkError(encoder, _writeKey(encoder, flKey));
    });
  }

  void writeKeyFLString(Pointer<FLEncoder> encoder, FLString key) {
    _checkError(encoder, _writeKey(encoder, key));
  }

  void writeKeyValue(Pointer<FLEncoder> encoder, FLValue key) {
    _checkError(encoder, _writeKeyValue(encoder, key));
  }

  void endDict(Pointer<FLEncoder> encoder) {
    _checkError(encoder, _endDict(encoder));
  }

  Data? finish(Pointer<FLEncoder> encoder) =>
      _checkError(encoder, _finish(encoder, globalFLErrorCode))
          .let(SliceResult.fromFLSliceResult)
          ?.toData();

  FLErrorCode _getError(Pointer<FLEncoder> encoder) =>
      __getError(encoder).toFleeceErrorCode();

  String _getErrorMessage(Pointer<FLEncoder> encoder) =>
      __getErrorMessage(encoder).toDartStringAndFree();

  T _checkError<T>(Pointer<FLEncoder> encoder, T result) {
    final mayHaveError = (result is bool && !result) ||
        (result is FLSliceResult && result.buf == nullptr);

    if (mayHaveError) {
      final errorCode = _getError(encoder);
      if (errorCode == FLErrorCode.noError) {
        return result;
      }

      throw CBLErrorException(
        CBLErrorDomain.fleece,
        errorCode,
        _getErrorMessage(encoder),
      );
    }

    return result;
  }
}

// === FleeceBindings ==========================================================

final class FleeceBindings extends Bindings {
  FleeceBindings(super.parent) {
    array = ArrayBindings(this);
    mutableArray = MutableArrayBindings(this);
    dict = DictBindings(this);
    dictKey = DictKeyBindings(this);
    mutableDict = MutableDictBindings(this);
    decoder = FleeceDecoderBindings(this);
    encoder = FleeceEncoderBindings(this);
  }

  late final ArrayBindings array;
  late final MutableArrayBindings mutableArray;
  late final DictBindings dict;
  late final DictKeyBindings dictKey;
  late final MutableDictBindings mutableDict;
  late final FleeceDecoderBindings decoder;
  late final FleeceEncoderBindings encoder;
}
