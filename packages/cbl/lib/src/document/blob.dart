// ignore_for_file: lines_longer_than_80_chars, avoid_equals_and_hash_code_on_mutable_classes

import 'dart:async';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../database/blob_store.dart';
import '../database/database.dart';
import '../errors.dart';
import '../fleece/encoder.dart';
import '../support/errors.dart';
import '../support/streams.dart';
import '../support/utils.dart';
import 'common.dart';
import 'document.dart';

const cblObjectTypeProperty = '@type';
const cblObjectTypeBlob = 'blob';

const blobDigestProperty = 'digest';
const blobDataProperty = 'data';
const blobLengthProperty = 'length';
const blobContentTypeProperty = 'content_type';

/// A Blob contains arbitrary binary data, tagged with a MIME type.
///
/// Blobs can be arbitrarily large, and their data is loaded only on demand
/// (when the [content] or [contentStream] properties are accessed), not when
/// the [Document] is loaded. The document’s raw JSON form only contains the
/// Blob’s metadata (type, [length] and a [digest] of the data) in a small
/// object. The data itself is stored externally to the document, keyed by the
/// digest.
///
/// The [digest] of a Blob is only available after it has been saved to a
/// [Database]. If a Blob is part of a [Document], it is automatically saved
/// when that document is being saved. Alternatively, a Blob can also be saved
/// explicitly, with [Database.saveBlob].
///
/// {@category Document}
abstract class Blob {
  /// Creates a [Blob] with the given in-memory data.
  factory Blob.fromData(String contentType, Uint8List data) =>
      BlobImpl.fromData(contentType, data);

  /// Creates a [Blob] from a [stream] of chunks of data.
  ///
  /// Usually, an unsaved [Blob] is saved when a [Document] that contains it is
  /// saved. This is not possible for [Blob]s created from a [stream], when the
  /// [Document] is being saved into a [SyncDatabase]. In this case, the [Blob]
  /// must be saved explicitly, with [Database.saveBlob].
  factory Blob.fromStream(String contentType, Stream<Uint8List> stream) =>
      BlobImpl.fromStream(contentType, stream);

  /// Gets the contents of this [Blob] as a block of memory.
  ///
  /// Not recommended for very large blobs, as it may be slow and use up lots of
  /// RAM.
  ///
  /// See also:
  ///
  /// - [contentStream] for streaming of the Blob's contents in chunks.
  Future<Uint8List> content();

  /// A stream of the content of this [Blob].
  Stream<Uint8List> contentStream();

  /// The type of content this [Blob] represents.
  ///
  /// By convention this is a MIME type.
  String? get contentType;

  /// The binary length of this [Blob].
  int? get length;

  /// The cryptographic digest of this [Blob]’s [content], which uniquely
  /// identifies it.
  String? get digest;

  /// The metadata representation of this [Blob].
  ///
  /// Blob metadata has the following properties:
  ///
  /// {@template cbl.Blob.metadataTable}
  ///
  /// | Property     | Type         | Description                                   | Required |
  /// | :----------- | :----------- | :-------------------------------------------- | :------- |
  /// | @type        | const "blob" | Marks dictionary as containing Blob metadata. | Yes      |
  /// | content_type | string       | Content type ex. text/plain.                  | No       |
  /// | length       | int          | Length of the Blob in bytes.                  | No       |
  /// | digest       | string       | Cryptographic digest of the Blob’s content.   | Yes      |
  ///
  /// {@endtemplate}
  ///
  /// See also:
  ///
  /// - [isBlob] to check if a [Map] contains valid Blob metadata.
  Map<String, Object?> get properties;

  /// Returns this blob's JSON representation.
  String toJson();

  /// Whether a plain Dart [Map] contains valid [Blob] metadata.
  ///
  /// See also:
  ///
  /// - [properties] for what is considered valid metadata.
  static bool isBlob(Map<String, Object?> properties) {
    if (!properties.containsKey(blobDigestProperty) ||
        properties[blobDigestProperty] is! String ||
        !properties.containsKey(cblObjectTypeProperty) ||
        properties[cblObjectTypeProperty] != cblObjectTypeBlob ||
        (properties.containsKey(blobContentTypeProperty) &&
            properties[blobContentTypeProperty] is! String) ||
        (properties.containsKey(blobLengthProperty) &&
            properties[blobLengthProperty] is! int)) {
      return false;
    }
    return true;
  }
}

// The semantics of a Blob are that it is immutable but the implementation is
// not.
// ignore: must_be_immutable
class BlobImpl implements Blob, FleeceEncodable, CblConversions {
  BlobImpl.fromData(String contentType, Uint8List data)
      : _contentType = contentType,
        _length = data.length,
        _content = data;

  BlobImpl.fromStream(String contentType, Stream<Uint8List> stream)
      : _contentType = contentType,
        _contentStream = stream;

  BlobImpl.fromProperties(
    Map<String, Object?> properties, {
    Database? database,
  })  : assert(properties[cblObjectTypeProperty] == cblObjectTypeBlob),
        _database = database,
        _contentType = properties[blobContentTypeProperty] as String?,
        // ignore: cast_nullable_to_non_nullable
        _length = properties[blobLengthProperty] as int,
        _digest = properties[blobDigestProperty] as String?,
        // ignore: unnecessary_parenthesis
        _content = (properties[blobDataProperty] as Uint8List?) {
    if (_digest == null && _content == null) {
      throw ArgumentError.value(
        properties,
        'properties',
        'Blob loaded from Database has neither the `digest` nor the `data` '
            'property.',
      );
    }
  }

  /// Max size of data that will be cached in memory with the [Blob].
  static const _maxCachedContentLength = 8 * 1024;

  static final _jsonEncoder = FleeceEncoder(format: FLEncoderFormat.json);

  Database? _database;
  BlobStore? get _blobStore => (_database as BlobStoreHolder?)?.blobStore;

  Uint8List? _content;
  Stream<Uint8List>? _contentStream;

  final String? _contentType;
  int? _length;
  String? _digest;

  @override
  String? get contentType => _contentType;

  @override
  int? get length => _length;

  @override
  String? get digest => _digest;

  @override
  Future<Uint8List> content() => byteStreamToFuture(contentStream());

  @override
  Stream<Uint8List> contentStream() {
    final content = _content;
    if (content != null) {
      return Stream.value(content);
    }

    final contentStream = _contentStream;
    if (contentStream != null) {
      if (contentStream is! RepeatableStream) {
        _contentStream = RepeatableStream(contentStream);
      }
      return _contentStream!;
    }

    if (_digest != null && _blobStore != null) {
      final stream = _blobStore!
          .readBlob(_blobProperties())
          ?.map((data) => data.toTypedList());
      if (stream == null) {
        _throwNotFoundError();
      }

      if (_shouldCacheContent) {
        final byteBuilder = BytesBuilder(copy: false);
        return stream.transform(StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            if (_content == null) {
              byteBuilder.add(data);
            }
            sink.add(UnmodifiableUint8ListView(data));
          },
          handleDone: (sink) {
            _content ??= byteBuilder.toBytes();
            sink.close();
          },
        ));
      }

      return stream;
    }

    _throwNotSavedError("Cannot load Blob's content.");
  }

  @override
  Map<String, Object?> get properties => _blobProperties();

  Map<String, Object?> _blobProperties({bool mayIncludeData = false}) => {
        cblObjectTypeProperty: cblObjectTypeBlob,
        if (_contentType != null) blobContentTypeProperty: _contentType,
        if (_length != null) blobLengthProperty: _length,
        if (_digest != null) blobDigestProperty: _digest,
        if (mayIncludeData && _digest == null) blobDataProperty: _content,
      };

  @override
  String toJson() {
    _jsonEncoder.reset();
    encodeTo(_jsonEncoder);
    return _jsonEncoder.finish().toDartString();
  }

  @override
  void encodeTo(FleeceEncoder encoder) {
    final extraInfo = encoder.extraInfo;
    final context = (extraInfo is FleeceEncoderContext) ? extraInfo : null;

    void writeProperties(Map<String, Object?> properties) {
      final blobProperties = _blobProperties(
        mayIncludeData: context?.encodeQueryParameter ?? false,
      );

      if (blobProperties[blobDigestProperty] == null &&
          blobProperties[blobDataProperty] == null) {
        _throwNotSavedError('Cannot serialize unsaved blob.');
      }

      encoder.writeDartObject(blobProperties);
    }

    if (context != null && context.saveExternalData) {
      final database = context.database;

      if (database != null) {
        // TODO: install blobs
        // return ensureIsInstalled(database).then(writeProperties);
      }
    }

    writeProperties(_blobProperties());
  }

  /// Ensures that this Blob is installed in [database] and returns the Blobs
  /// metadata.
  ///
  /// If this Blob has a [digest] it is assumed that the Blob is installed.
  ///
  /// If [allowFromStreamForSyncDatabase] is `true` and this Blob was created
  /// from a [Stream] and the database is a [SyncDatabase] it will be installed
  /// and the result will be a Future. Otherwise a [StateError] is thrown.
  FutureOr<Map<String, Object?>> ensureIsInstalled(
    Database database, {
    bool allowFromStreamForSyncDatabase = false,
  }) {
    assertMatchingDatabase(_database, database, 'Blob');
    _database = database;

    Map<String, Object?> updateProperties(Map<String, Object?> metadata) {
      _digest = metadata[blobDigestProperty] as String?;
      _length = metadata[blobLengthProperty] as int?;
      return metadata;
    }

    if (_digest == null) {
      assert(_content != null || _contentStream != null);

      final blobStore = _blobStore!;

      if (_content != null) {
        if (blobStore is SyncBlobStore) {
          return blobStore
              .saveBlobFromDataSync(
                _contentType!,
                _content!.toData(),
              )
              .let(updateProperties);
        } else {
          return blobStore
              .saveBlobFromData(_contentType!, _content!.toData())
              .then(updateProperties);
        }
      } else {
        if (blobStore is SyncBlobStore && !allowFromStreamForSyncDatabase) {
          _throwFromStreamNotAllowedError();
        }

        final stream = _contentStream!.map((chunk) => chunk.toData());
        _contentStream = null;
        return blobStore
            .saveBlobFromStream(_contentType!, stream)
            .then(updateProperties);
      }
    }

    return _blobProperties();
  }

  @override
  Object? toCblObject() => this;

  @override
  Object? toPlainObject() => this;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! BlobImpl || runtimeType != other.runtimeType) {
      return false;
    }

    if (_digest == null || other._digest == null) {
      return false;
    }

    return _digest == other._digest;
  }

  @override
  int get hashCode {
    if (_digest == null) {
      return 31;
    }

    return _digest.hashCode;
  }

  @override
  String toString() {
    final contentType = _contentType != null ? '$_contentType; ' : '';
    final length = _length != null
        ? '${((_length! + 512) / 1024).toStringAsFixed(1)} KB'
        : '? KB';
    return 'Blob($contentType$length)';
  }

  bool get _shouldCacheContent => _length! <= _maxCachedContentLength;

  Never _throwNotSavedError(String message) {
    throw StateError(
      '$message Save the Blob or a Document containing the Blob, first.',
    );
  }

  Never _throwFromStreamNotAllowedError() {
    throw StateError(
      'Blobs created from Streams cannot be saved automatically, when the '
      'containing Document is saved into a SyncDatabase. '
      'Use SyncDatabase.saveBlob to save the Blob first.',
    );
  }

  Never _throwNotFoundError() {
    throw DatabaseException(
      'Could not find Blob in $_database: $_blobProperties',
      DatabaseErrorCode.notFound,
    );
  }
}

void checkBlobMetadata(Map<String, Object?> properties) {
  if (!Blob.isBlob(properties)) {
    throw ArgumentError.value(
      properties,
      'properties',
      'does not contain valid Blob metadata',
    );
  }
}
