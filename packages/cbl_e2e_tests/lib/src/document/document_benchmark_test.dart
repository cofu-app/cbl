import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cbl/cbl.dart';

import '../../test_binding_impl.dart';
import '../test_binding.dart';
import '../utils/benchmark.dart';
import '../utils/database_utils.dart';

/// Benchmark that measures the performance of looking up properties in a
/// document.
class DocumentPropertyLookup extends BenchmarkBase {
  DocumentPropertyLookup() : super('Document property lookup');

  static const properties = 100;

  late final SyncDatabase db;
  late final String id;

  @override
  void setup() {
    db = openSyncTestDatabase();
    final doc = MutableDocument({
      for (final i in Iterable<int>.generate(properties)) 'key$i': true,
    });
    id = doc.id;
    db.saveDocument(doc);
  }

  @override
  void teardown() {
    db.close();
  }

  @override
  void run() {
    // We want to measure the time it takes to look up a property for the first
    // time. Looking up a property for the second time is fast because entries
    // are cached, which is why we load a new document each time.
    // To offset the time it takes to load a document, we access multiple
    // properties.
    final doc = db.document(id)!;
    for (final i in Iterable<int>.generate(properties)) {
      doc.value('key$i');
    }
  }
}

void main() {
  setupTestBinding();

  test('Document benchmark', () {
    runBenchmarks([
      DocumentPropertyLookup(),
    ]);
  });
}
