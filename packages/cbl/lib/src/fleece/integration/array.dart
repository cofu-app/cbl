import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:collection/collection.dart';

import '../../support/ffi.dart';
import '../../support/utils.dart';
import '../encoder.dart';
import 'collection.dart';
import 'value.dart';

final _arrayBindings = cblBindings.fleece.array;

class MArray extends MCollection {
  MArray()
      : _array = null,
        _values = [];

  MArray.asCopy(MArray super.original, {bool? isMutable})
      : _array = original._array,
        _values = original._values
            .map((value) => value?.clone())
            .toList(growable: isMutable ?? original.isMutable),
        super.asCopy(isMutable: isMutable ?? original.isMutable);

  MArray.asChild(super.slot, super.parent, int length, {bool? isMutable})
      : _array = slot.value!.cast(),
        _values = List<MValue?>.filled(
          length,
          null,
          growable: isMutable ?? parent.hasMutableChildren,
        ),
        super.asChild(
          isMutable: isMutable ?? parent.hasMutableChildren,
        );

  final Pointer<FLArray>? _array;
  final List<MValue?> _values;

  int get length => _values.length;

  MValue? get(int index) {
    assert(index >= 0);

    if (index >= _values.length) {
      return null;
    }

    var value = _values[index];
    if (value == null) {
      value = _values[index] = _loadMValue(index);
      cblReachabilityFence(context);
    }

    return value;
  }

  bool set(int index, Object? native) {
    assert(isMutable);
    assert(index >= 0);

    if (index >= length) {
      return false;
    }

    mutate();
    (_values[index] ??= MValue.empty()).setNative(native);

    return true;
  }

  bool insert(int index, Object? native) {
    assert(isMutable);
    assert(index >= 0);

    final length = this.length;
    if (index > length) {
      return false;
    } else if (index < length) {
      _populateValues();
    }

    mutate();
    _values.insert(index, MValue.empty()..setNative(native));

    return true;
  }

  void append(Object? native) => insert(length, native);

  bool remove(int index, [int count = 1]) {
    assert(isMutable);
    assert(index >= 0);
    assert(count >= 0);

    final end = index + count;
    if (end > length) {
      return false;
    }

    if (count == 0) {
      return true;
    }

    if (end < length) {
      _populateValues();
    }

    mutate();
    _values.getRange(index, end).forEach((value) => value?.removeFromParent());
    _values.removeRange(index, end);

    return true;
  }

  void clear() {
    assert(isMutable);

    if (_values.isEmpty) {
      return;
    }

    mutate();
    _values
      ..forEach((value) => value?.removeFromParent())
      ..clear();
  }

  @override
  void performEncodeTo(FleeceEncoder encoder) {
    if (!isMutated) {
      encoder.writeValue(_array!.cast());
    } else {
      encoder.beginArray(length);
      var index = 0;
      for (final value in _values) {
        if (value == null) {
          encoder.writeArrayValue(_array!, index);
        } else {
          value.encodeTo(encoder);
        }
        ++index;
      }
      encoder.endArray();
    }
  }

  @override
  Iterable<MValue> get values => _values.whereNotNull();

  Iterable<MValue> get iterable sync* {
    final length = _values.length;
    for (var i = 0; i < length; ++i) {
      yield _values[i] ??= _loadMValue(i);
    }

    cblReachabilityFence(context);
  }

  void _populateValues() {
    if (_array == null) {
      return;
    }

    var i = 0;
    for (final value in _values) {
      if (value == null) {
        _values[i] = _loadMValue(i);
      }
      i++;
    }

    cblReachabilityFence(context);
  }

  MValue _loadMValue(int index) =>
      _arrayBindings.get(_array!, index).let(MValue.withValue);
}
