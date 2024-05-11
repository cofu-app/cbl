import 'package:cbl_native_assets/cbl.dart';
import 'package:cbl_native_assets/src/bindings.dart';
import 'package:cbl_native_assets/src/document/array.dart';
import 'package:cbl_native_assets/src/document/dictionary.dart';
import 'package:cbl_native_assets/src/fleece/containers.dart' show Doc;
import 'package:cbl_native_assets/src/fleece/decoder.dart';
import 'package:cbl_native_assets/src/fleece/dict_key.dart';
import 'package:cbl_native_assets/src/fleece/encoder.dart';
import 'package:cbl_native_assets/src/fleece/integration/integration.dart';

MContext createTestMContext(Object data) => MContext(
      data: data,
      dictKeys: OptimizingDictKeys(),
      sharedKeysTable: SharedKeysTable(),
      sharedStringsTable: SharedStringsTable(),
    );

Array immutableArray([List<Object?>? data]) {
  final array = MutableArray(data) as MutableArrayImpl;
  final encoder = FleeceEncoder();
  array.encodeTo(encoder);
  final fleeceData = encoder.finish();
  final root = MRoot.fromContext(
    createTestMContext(Doc.fromResultData(fleeceData, FLTrust.trusted)),
    isMutable: false,
  );
  // ignore: cast_nullable_to_non_nullable
  return root.asNative as Array;
}

Dictionary immutableDictionary([Map<String, Object?>? data]) {
  final array = MutableDictionary(data) as MutableDictionaryImpl;
  final encoder = FleeceEncoder();
  array.encodeTo(encoder);
  final fleeceData = encoder.finish();
  final root = MRoot.fromContext(
    createTestMContext(Doc.fromResultData(fleeceData, FLTrust.trusted)),
    isMutable: false,
  );
  // ignore: cast_nullable_to_non_nullable
  return root.asNative as Dictionary;
}
