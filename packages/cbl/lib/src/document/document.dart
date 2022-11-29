// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:async';
import 'dart:collection';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../database/database_base.dart';
import '../fleece/containers.dart' show Doc;
import '../fleece/decoder.dart';
import '../fleece/dict_key.dart';
import '../fleece/encoder.dart';
import '../fleece/integration/integration.dart';
import '../support/encoding.dart';
import '../support/errors.dart';
import '../support/utils.dart';
import 'array.dart';
import 'blob.dart';
import 'common.dart';
import 'dictionary.dart';
import 'fragment.dart';

/// A Couchbase Lite document.
///
/// The [Document] is immutable.
///
/// {@category Document}
abstract class Document implements DictionaryInterface, Iterable<String> {
  /// The document’s id.
  String get id;

  /// The id representing the document’s revision.
  String? get revisionId;

  /// Sequence number of the document in the database.
  ///
  /// This indicates how recently the document has been changed: every time any
  /// document is updated, the database assigns it the next sequential sequence
  /// number. Thus, if a document’s sequence property changes that means it’s
  /// been changed (on-disk); and if one document’s sequence is greater than
  /// another’s, that means it was changed more recently.
  int get sequence;

  /// Returns a mutable copy of the document.
  MutableDocument toMutable();

  /// Returns this document's properties as JSON.
  String toJson();
}

/// A mutable version of [Document].
///
/// {@category Document}
abstract class MutableDocument implements Document, MutableDictionaryInterface {
  /// Creates a new [MutableDocument] with a random UUID, optionally initialized
  /// with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDocument([Map<String, Object?>? data]) =>
      MutableDelegateDocument(data);

  /// Creates a new [MutableDocument] with a given [id], optionally initialized
  /// with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDocument.withId(String id, [Map<String, Object?>? data]) =>
      MutableDelegateDocument.withId(id, data);
}

/// An interface to abstract over the differences between the documents of the
/// different database implementations.
abstract class DocumentDelegate {
  /// The document's id.
  String get id;

  /// The document's revision id.
  String? get revisionId;

  /// The document's sequence number.
  int get sequence;

  /// The document's encoded properties.
  EncodedData? get properties;

  set properties(EncodedData? value);

  /// Creates a new [MRoot] which contains the documents properties, based on
  /// the current state of this delegate.
  ///
  /// The returned [MRoot] must have the mutability as required by [isMutable].
  MRoot createMRoot(DelegateDocument document, {required bool isMutable});

  /// Returns a copy of this delegate which can be used for a mutable document.
  DocumentDelegate toMutable();
}

/// A [DocumentDelegate] that is used when a new [MutableDocument] is created,
/// until it is saved.
///
/// When a new [MutableDocument] is created there is no way to know into which
/// database it will be saved. Until that point this type of delegate is used.
/// This way there is no need to have one type of document for each database
/// implementation or have a factory create new documents.
class NewDocumentDelegate extends DocumentDelegate {
  NewDocumentDelegate([String? id, this.properties]) : id = id ?? createUuid();

  NewDocumentDelegate.mutableCopy(NewDocumentDelegate delegate)
      : id = delegate.id,
        properties = delegate.properties;

  @override
  final String id;

  @override
  String? get revisionId => null;

  @override
  int get sequence => 0;

  @override
  EncodedData? properties;

  @override
  MRoot createMRoot(DelegateDocument document, {required bool isMutable}) {
    assert(isMutable);

    final properties = this.properties;
    if (properties != null) {
      // Usually a new document doesn't have properties, unless it is being
      // used to insert a document that was created remotely (meaning another
      // isolate or even process).
      return MRoot.fromContext(
        DocumentMContext(
          document,
          data: Doc.fromResultData(properties.toFleece(), FLTrust.trusted),
        ),
        isMutable: isMutable,
      );
    }

    return MRoot.fromNative(
      MutableDictionary(),
      context: DocumentMContext(document),
      isMutable: isMutable,
    );
  }

  @override
  DocumentDelegate toMutable() => NewDocumentDelegate.mutableCopy(this);
}

/// The context for [MCollection]s within a [DelegateDocument].
class DocumentMContext implements DatabaseMContext {
  DocumentMContext(this.document, {this.data});

  /// The [DelegateDocument] to which [MCollection]s with this context belong
  /// to.
  final DelegateDocument document;

  @override
  final Object? data;

  @override
  DictKeys get dictKeys =>
      (_dictKeys ??= database?.dictKeys) ?? const UnoptimizingDictKeys();
  DictKeys? _dictKeys;

  @override
  SharedKeysTable get sharedKeysTable =>
      (_sharedKeysTable ??= database?.sharedKeysTable) ??
      const NoopSharedKeysTable();
  SharedKeysTable? _sharedKeysTable;

  @override
  final sharedStringsTable = SharedStringsTable();

  @override
  DatabaseBase? get database => document._database;
}

class DelegateDocument with IterableMixin<String> implements Document {
  DelegateDocument(
    DocumentDelegate delegate, {
    DatabaseBase? database,
  })  : _delegate = delegate,
        _database = database {
    _setupProperties();
  }

  static final _encoders = {
    for (final format in EncodingFormat.values)
      format: FleeceEncoder(format: format.toFLEncoderFormat())
  };

  DocumentDelegate get delegate => _delegate;
  DocumentDelegate _delegate;

  void setDelegate(
    DocumentDelegate delegate, {
    bool updateProperties = true,
  }) {
    if (_delegate == delegate) {
      return;
    }

    _delegate = delegate;

    if (updateProperties) {
      _setupProperties();
    }
  }

  DatabaseBase? get database => _database;
  DatabaseBase? _database;

  set database(DatabaseBase? database) {
    if (assertMatchingDatabase(_database, database!, 'Document')) {
      _database = database;
    }
  }

  void setEncodedProperties(EncodedData properties) {
    delegate.properties = properties;
    _setupProperties();
  }

  FutureOr<EncodedData> encodeProperties({
    EncodingFormat format = EncodingFormat.fleece,
    bool saveExternalData = false,
  }) {
    final encoder = _encoders[format]!
      ..reset()
      ..extraInfo = FleeceEncoderContext(
        database: database,
        encodeQueryParameter: true,
        saveExternalData: saveExternalData,
      );
    _root.encodeTo(encoder);
    // TODO: install blobs
    return EncodedData(format, encoder.finish());
  }

  FutureOr<void> writePropertiesToDelegate() =>
      encodeProperties(saveExternalData: true)
          .then((properties) => delegate.properties = properties);

  bool get _isMutable => false;
  String get _typeName => 'Document';

  void _setupProperties() {
    _root = delegate.createMRoot(this, isMutable: _isMutable);
    _properties = _root.asNative! as Dictionary;
  }

  late MRoot _root;

  late Dictionary _properties;

  @override
  String get id => _delegate.id;

  @override
  String? get revisionId => _delegate.revisionId;

  @override
  int get sequence => _delegate.sequence;

  @override
  int get length => _properties.length;

  @override
  List<String> get keys => _properties.keys;

  @override
  T? value<T extends Object>(String key) => _properties.value(key);

  @override
  String? string(String key) => _properties.string(key);

  @override
  int integer(String key) => _properties.integer(key);

  @override
  double float(String key) => _properties.float(key);

  @override
  num? number(String key) => _properties.number(key);

  @override
  bool boolean(String key) => _properties.boolean(key);

  @override
  DateTime? date(String key) => _properties.date(key);

  @override
  Blob? blob(String key) => _properties.blob(key);

  @override
  Array? array(String key) => _properties.array(key);

  @override
  Dictionary? dictionary(String key) => _properties.dictionary(key);

  @override
  Fragment operator [](String key) => _properties[key];

  @override
  Map<String, Object?> toPlainMap() => _properties.toPlainMap();

  @override
  MutableDocument toMutable() => MutableDelegateDocument.fromDelegate(
        delegate.toMutable(),
        database: _database,
      );

  @override
  String toJson() => _properties.toJson();

  @override
  Iterator<String> get iterator => _properties.iterator;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DelegateDocument &&
          (_database == other._database ||
              _database?.name == other._database?.name) &&
          id == other.id &&
          _properties == other._properties;

  @override
  int get hashCode =>
      (_database?.name).hashCode ^ id.hashCode ^ _properties.hashCode;

  @override
  String toString() => '$_typeName('
      'id: $id, '
      'revisionId: $revisionId, '
      // ignore: missing_whitespace_between_adjacent_strings
      'sequence: $sequence'
      ')';
}

class MutableDelegateDocument extends DelegateDocument
    implements MutableDocument {
  MutableDelegateDocument([Map<String, Object?>? data])
      : this.fromDelegate(NewDocumentDelegate(), data: data);

  MutableDelegateDocument.withId(String id, [Map<String, Object?>? data])
      : this.fromDelegate(NewDocumentDelegate(id), data: data);

  MutableDelegateDocument.fromDelegate(
    super.delegate, {
    super.database,
    Map<String, Object?>? data,
  }) {
    if (data != null) {
      setData(data);
    }
  }

  @override
  String get _typeName => 'MutableDocument';

  @override
  bool get _isMutable => true;

  late MutableDictionary _mutableProperties;

  @override
  void _setupProperties() {
    super._setupProperties();
    _mutableProperties = _properties as MutableDictionary;
  }

  @override
  void setValue(Object? value, {required String key}) =>
      _mutableProperties.setValue(value, key: key);

  @override
  void setString(String? value, {required String key}) =>
      _mutableProperties.setString(value, key: key);

  @override
  void setInteger(int value, {required String key}) =>
      _mutableProperties.setInteger(value, key: key);

  @override
  void setFloat(double value, {required String key}) =>
      _mutableProperties.setFloat(value, key: key);

  @override
  void setNumber(num? value, {required String key}) =>
      _mutableProperties.setNumber(value, key: key);

  @override
  void setBoolean(bool value, {required String key}) =>
      _mutableProperties.setBoolean(value, key: key);

  @override
  void setDate(DateTime? value, {required String key}) =>
      _mutableProperties.setDate(value, key: key);

  @override
  void setBlob(Blob? value, {required String key}) =>
      _mutableProperties.setBlob(value, key: key);

  @override
  void setArray(Array? value, {required String key}) =>
      _mutableProperties.setArray(value, key: key);

  @override
  void setDictionary(Dictionary? value, {required String key}) =>
      _mutableProperties.setDictionary(value, key: key);

  @override
  void setData(Map<String, Object?> data) => _mutableProperties.setData(data);

  @override
  void removeValue(String key) => _mutableProperties.removeValue(key);

  @override
  MutableArray? array(String key) => _mutableProperties.array(key);

  @override
  MutableDictionary? dictionary(String key) =>
      _mutableProperties.dictionary(key);

  @override
  MutableFragment operator [](String key) => _mutableProperties[key];

  @override
  MutableDocument toMutable() => MutableDelegateDocument.fromDelegate(
        delegate.toMutable(),
        database: _database,
        // We make a deep copy of the properties, to include modifications of
        // this document, which have not been synced with the delegate, in the
        // copy.
        data: toPlainMap(),
      );
}
