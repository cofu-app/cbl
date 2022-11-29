import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../database/database_base.dart';
import '../database/ffi_database.dart';
import '../document/common.dart';
import '../fleece/containers.dart' as fl;
import '../fleece/encoder.dart';
import '../support/async_callback.dart';
import '../support/errors.dart';
import '../support/ffi.dart';
import '../support/listener_token.dart';
import '../support/native_object.dart';
import '../support/streams.dart';
import '../support/tracing.dart';
import '../support/utils.dart';
import '../tracing.dart';
import '../typed_data.dart';
import 'data_source.dart';
import 'expressions/expression.dart';
import 'join.dart';
import 'ordering.dart';
import 'parameters.dart';
import 'query.dart';
import 'query_builder.dart';
import 'query_change.dart';
import 'result.dart';
import 'result_set.dart';
import 'select_result.dart';

final _bindings = cblBindings.query;

class FfiQuery extends QueryBase implements SyncQuery, Finalizable {
  FfiQuery({
    FfiDatabase? super.database,
    required super.language,
    super.definition,
  }) : super(typeName: 'FfiQuery');

  var _isPrepared = false;

  late final _listenerTokens = ListenerTokenRegistry(this);

  @override
  FfiDatabase? get database => super.database as FfiDatabase?;

  late final Pointer<CBLQuery> _pointer;

  List<String> get columnNames => useSync(() => _columnNames);
  late final List<String> _columnNames;

  @override
  Parameters? get parameters => _parameters;
  ParametersImpl? _parameters;

  @override
  void setParameters(Parameters? value) => useSync(() {
        if (value == null) {
          _parameters = null;
        } else {
          _parameters = ParametersImpl.from(value);
        }
        _applyParameters();
      });

  @override
  SyncResultSet execute() => syncOperationTracePoint(
        () => ExecuteQueryOp(this),
        () => useSync(
          () => FfiResultSet(
            runWithErrorTranslation(() => _bindings.execute(_pointer)),
            query: this,
            columnNames: _columnNames,
          ),
        ),
      );

  @override
  String explain() => useSync(() => _bindings.explain(_pointer));

  @override
  ListenerToken addChangeListener(
    QueryChangeListener<SyncResultSet> listener,
  ) =>
      useSync(() => _addChangeListener(listener).also(_listenerTokens.add));

  AbstractListenerToken _addChangeListener(
    QueryChangeListener<SyncResultSet> listener,
  ) {
    late Pointer<CBLListenerToken> listenerToken;
    final database = this.database!;
    final callback = AsyncCallback(
      (_) {
        final results = FfiResultSet(
          // The native side sends no arguments. When the native side
          // notifies the listener it has to copy the current query
          // result set.
          _bindings.copyCurrentResults(_pointer, listenerToken),
          query: this,
          columnNames: _columnNames,
        );

        final change = QueryChange(this, results);
        listener(change);
        return null;
      },
      debugName: 'FfiQuery.addChangeListener',
    );

    listenerToken = _bindings.addChangeListener(
      database.pointer,
      _pointer,
      callback.pointer,
    );

    return FfiListenerToken(callback);
  }

  @override
  void removeChangeListener(ListenerToken token) => useSync(() {
        final result = _listenerTokens.remove(token);
        assert(result is! Future);
      });

  @override
  Stream<QueryChange<SyncResultSet>> changes() => useSync(() => ListenerStream(
        parent: this,
        addListener: _addChangeListener,
      ));

  @override
  T useSync<T>(T Function() f) => super.useSync(() {
        prepare();
        return f();
      });

  void prepare() {
    if (_isPrepared) {
      return;
    }
    _isPrepared = true;
    attachToParentResource();
    _performPrepare();
  }

  void _performPrepare() {
    syncOperationTracePoint(() => PrepareQueryOp(this), () {
      _pointer = runWithErrorTranslation(
        () => _bindings.create(database!.pointer, language, definition!),
      );

      bindCBLRefCountedToDartObject(this, pointer: _pointer);

      _columnNames = List.generate(
        _bindings.columnCount(_pointer),
        (index) => _bindings.columnName(_pointer, index),
      );
    });
  }

  void _applyParameters() {
    final encoder = FleeceEncoder()
      ..extraInfo = FleeceEncoderContext(encodeQueryParameter: true);
    final parameters = _parameters;
    if (parameters != null) {
      parameters.encodeTo(encoder);
    } else {
      encoder
        ..beginDict(0)
        ..endDict();
    }
    final data = encoder.finish();
    final doc = fl.Doc.fromResultData(data, FLTrust.trusted);
    final dict = doc.root.asDict!;
    _bindings.setParameters(_pointer, dict.pointer.cast());
  }
}

class FfiResultSet with IterableMixin<Result> implements SyncResultSet {
  FfiResultSet(
    Pointer<CBLResultSet> pointer, {
    required FfiQuery query,
    required List<String> columnNames,
  })  : _database = query.database!,
        _columnNames = columnNames,
        _iterator = ResultSetIterator.fromPointer(pointer),
        _context = createResultSetMContext(query.database!);

  final DatabaseBase _database;
  final List<String> _columnNames;
  final ResultSetIterator _iterator;

  final DatabaseMContext _context;
  ResultImpl? _current;

  @override
  Iterable<D> asTypedIterable<D extends TypedDictionaryObject>() {
    final adapter = _database.useWithTypedData();
    return map((_) => _current!.asDictionary)
        .map(adapter.dictionaryFactoryForType<D>());
  }

  @override
  Stream<Result> asStream() => Stream.fromIterable(this);

  @override
  Stream<D> asTypedStream<D extends TypedDictionaryObject>() =>
      Stream.fromIterable(asTypedIterable<D>());

  @override
  List<Result> allResults() => toList();

  @override
  List<D> allTypedResults<D extends TypedDictionaryObject>() =>
      asTypedIterable<D>().toList();

  @override
  Iterator<Result> get iterator => this;

  @override
  Result get current => _current ??= ResultImpl.fromValuesArray(
        _iterator.current,
        // Results from the same result set can share the same context, because
        // in CBL C, a result set is encoded in a single Fleece doc.
        context: _context,
        columnNames: _columnNames,
      );

  @override
  bool moveNext() {
    _current = null;
    return _iterator.moveNext();
  }

  @override
  String toString() => 'FfiResultSet()';
}

class ResultSetIterator
    with IterableMixin<fl.Array>
    implements Iterator<fl.Array>, Finalizable {
  ResultSetIterator.fromPointer(this._pointer, {this.encodeArray = false}) {
    bindCBLRefCountedToDartObject(this, pointer: _pointer);
  }

  static final _bindings = cblBindings.resultSet;

  final bool encodeArray;
  final Pointer<CBLResultSet> _pointer;
  var _isDone = false;
  fl.Array? _current;

  @override
  Iterator<fl.Array> get iterator => this;

  @override
  fl.Array get current {
    assert(_current != null || !_isDone);
    final result =
        _current ??= fl.Array.fromPointer(_bindings.resultArray(_pointer));
    return result;
  }

  @override
  bool moveNext() {
    if (_isDone) {
      return false;
    }
    _current = null;
    _isDone = !_bindings.next(_pointer);
    return !_isDone;
  }
}

abstract class SyncBuilderQuery extends FfiQuery with BuilderQueryMixin {
  SyncBuilderQuery({
    BuilderQueryMixin? query,
    Iterable<SelectResultInterface>? selects,
    bool? distinct,
    DataSourceInterface? from,
    Iterable<JoinInterface>? joins,
    ExpressionInterface? where,
    Iterable<ExpressionInterface>? groupBys,
    ExpressionInterface? having,
    Iterable<OrderingInterface>? orderings,
    ExpressionInterface? limit,
    ExpressionInterface? offset,
  }) : super(
          database: (from as DataSourceImpl?)?.database as FfiDatabase? ??
              query?.database as FfiDatabase?,
          language: CBLQueryLanguage.json,
        ) {
    initBuilderQuery(
      query: query,
      selects: selects,
      distinct: distinct,
      from: from,
      joins: joins,
      where: where,
      groupBys: groupBys,
      having: having,
      orderings: orderings,
      limit: limit,
      offset: offset,
    );
  }
}
