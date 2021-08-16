import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../../support/native_object.dart';
import '../encoder.dart';
import 'collection.dart';
import 'context.dart';
import 'value.dart';

class MRoot extends MCollection {
  MRoot.fromData(
    Uint8List data, {
    required MContext context,
    required bool isMutable,
  })  : data = data.toSliceResult(),
        super(context: context, isMutable: isMutable) {
    _slot = MValue.withValue(context.decoder.loadValueFromData(this.data!)!);
    _slot.updateParent(this);
  }

  MRoot.fromValue(
    Pointer<FLValue> value, {
    required MContext context,
    required bool isMutable,
  })  : value = FleeceValueObject(value, isRefCounted: true, adopt: false),
        _slot = MValue.withValue(context.decoder.loadValue(value)!),
        super(context: context, isMutable: isMutable) {
    _slot.updateParent(this);
  }

  SliceResult? data;

  FleeceValueObject<FLValue>? value;

  late final MValue _slot;

  @override
  MContext get context => super.context!;

  @override
  bool get isMutated => _slot.isMutated;

  @override
  Iterable<MValue> get values => [_slot];

  @override
  FutureOr<void> performEncodeTo(FleeceEncoder encoder) =>
      _slot.encodeTo(encoder);

  Object? get asNative => _slot.asNative(this);

  SliceResult encode() {
    final encoder = FleeceEncoder();
    final result = encodeTo(encoder);
    assert(result is! Future);
    return encoder.finish();
  }
}
