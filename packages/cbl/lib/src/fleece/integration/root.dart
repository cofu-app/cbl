import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../containers.dart';
import '../encoder.dart';
import 'collection.dart';
import 'context.dart';
import 'value.dart';

class MRoot extends MCollection {
  MRoot.fromContext(
    MContext context, {
    required super.isMutable,
  })  : _slot = MValue.withValue(context.flValue),
        super(context: context) {
    _slot.updateParent(this);
  }

  MRoot.fromNative(
    Object native, {
    required MContext super.context,
    required super.isMutable,
  })  : assert(native is! Pointer),
        assert(context.data == null),
        _slot = MValue.withNative(native) {
    _slot.updateParent(this);
  }

  static final _encoder = FleeceEncoder();

  final MValue _slot;

  @override
  bool get isMutated => _slot.isMutated;

  @override
  Iterable<MValue> get values => [_slot];

  @override
  void performEncodeTo(FleeceEncoder encoder) => _slot.encodeTo(encoder);

  Object? get asNative => _slot.asNative(this);

  Data encode() {
    _encoder.reset();
    encodeTo(_encoder);
    return _encoder.finish();
  }
}

extension on MContext {
  Pointer<FLValue> get flValue {
    final data = this.data;
    if (data is Doc) {
      return data.root.pointer;
    } else if (data is Value) {
      return data.pointer;
    } else {
      throw UnsupportedError('Unsupported MContext.data value: $data');
    }
  }
}
