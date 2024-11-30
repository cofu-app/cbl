import 'dart:ffi';

import '../../bindings.dart';
import '../../bindings/cblite.dart' as cblite;
import '../../document/array.dart';
import '../../fleece/containers.dart';
import '../../fleece/integration/integration.dart';
import '../../query.dart';
import '../../support/errors.dart';
import '../../support/resource.dart';
import 'ffi_query_index.dart';

final _bindings = CBLBindings.instance.indexUpdater;

final class FfiIndexUpdater
    with ClosableResourceMixin, ArrayInterfaceMixin
    implements SyncIndexUpdater, Finalizable {
  FfiIndexUpdater.fromPointer(
    this.pointer, {
    required FfiQueryIndex index,
  }) {
    CBLBindings.instance.base
        .bindCBLRefCountedToDartObject(this, pointer.cast());
    needsToBeClosedByParent = false;
    attachTo(index);
  }

  final Pointer<cblite.CBLIndexUpdater> pointer;

  Value flValue(int index) =>
      Value.fromPointer(_bindings.value(pointer, index));

  @override
  Object? cblValue(int index) => useSync(
        () => MRoot.fromContext(
          MContext(data: flValue(index)),
          isMutable: false,
        ).asNative,
      );

  @override
  int get length => useSync(
        () => runWithErrorTranslation(
          () => _bindings.count(pointer),
        ),
      );

  @override
  void setVector(int index, List<double>? vector) => useSync(
        () => runWithErrorTranslation(
          () => _bindings.setVector(pointer, index, vector),
        ),
      );

  @override
  void skipVector(int index) => useSync(
        () => runWithErrorTranslation(
          () => _bindings.skipVector(pointer, index),
        ),
      );

  @override
  void finish() => useSync(
        () => runWithErrorTranslation(
          () => _bindings.finish(pointer),
        ),
      );
}
