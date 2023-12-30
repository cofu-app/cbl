import 'package:cbl_ffi/cbl_ffi.dart';

import '../database/database.dart';
import '../errors.dart';

Never throwNotInitializedError() {
  throw StateError('Couchbase Lite must be initialized before using it.');
}

Never throwAlreadyInitializedError() {
  throw StateError('Couchbase Lite has already been initialized.');
}

T assertArgumentType<T>(Object? value, String name) {
  if (value is! T) {
    throw ArgumentError.value(value, name, 'must be of type $T');
  }
  return value;
}

void assertIndexOrKey(Object? indexOrKey) {
  if (indexOrKey is! int && indexOrKey is! String) {
    throw ArgumentError.value(
      indexOrKey,
      'indexOrKey',
      'must be of type int or String',
    );
  }
}

String assertKey(Object? key) => assertArgumentType<String>(key, 'key');

bool assertMatchingDatabase(
  Database? current,
  Database target,
  String valueType,
) {
  if (current == null) {
    return true;
  }

  if (current == target) {
    return false;
  }

  throw StateError(
    '$valueType cannot be used with database ${target.name} because it '
    'already belongs to database ${current.name}.',
  );
}

const _toCouchbaseLiteException = toCouchbaseLiteException;

extension CBLErrorExceptionExt on CBLErrorException {
  CouchbaseLiteException toCouchbaseLiteException() =>
      _toCouchbaseLiteException(this);
}

@pragma('vm:prefer-inline')
T runWithErrorTranslation<T>(T Function() fn) {
  try {
    return fn();
  } on CBLErrorException catch (e) {
    throw toCouchbaseLiteException(e);
  }
}

CouchbaseLiteException toCouchbaseLiteException(CBLErrorException exception) {
  switch (exception.domain) {
    case CBLErrorDomain.couchbaseLite:
      return DatabaseException(
        exception.message,
        // ignore: cast_nullable_to_non_nullable
        (exception.code as CBLErrorCode).toDatabaseErrorCode(),
        errorPosition: exception.errorPosition,
        queryString: exception.errorSource,
      );
    case CBLErrorDomain.posix:
      return PosixException(exception.message, exception.code! as int);
    case CBLErrorDomain.sqLite:
      return SQLiteException(exception.message, exception.code! as int);
    case CBLErrorDomain.fleece:
      final code = exception.code! as FLErrorCode;
      return FleeceException('${exception.message} (${code.name}))');
    case CBLErrorDomain.network:
      return NetworkException(
        exception.message,
        // ignore: cast_nullable_to_non_nullable
        (exception.code as CBLNetworkErrorCode).toNetworkErrorCode(),
      );
    case CBLErrorDomain.webSocket:
      String formatMessage(Object? enumCode) => enumCode != null
          ? exception.message
          : '${exception.message} (${exception.code})';

      // ignore: cast_nullable_to_non_nullable
      if (exception.code as int < 1000) {
        final code = _httpErrorCodeMap[exception.code];
        return HttpException(formatMessage(code), code);
      } else {
        final code = _webSocketErrorCodeMap[exception.code];
        return WebSocketException(formatMessage(code), code);
      }
  }
}

extension on CBLErrorCode {
  DatabaseErrorCode toDatabaseErrorCode() => DatabaseErrorCode.values[index];
}

extension on CBLNetworkErrorCode {
  NetworkErrorCode toNetworkErrorCode() => NetworkErrorCode.values[index];
}

const _httpErrorCodeMap = {
  401: HttpErrorCode.authRequired,
  403: HttpErrorCode.forbidden,
  404: HttpErrorCode.notFound,
  409: HttpErrorCode.conflict,
  407: HttpErrorCode.proxyAuthRequired,
  413: HttpErrorCode.entityTooLarge,
  418: HttpErrorCode.imATeapot,
  500: HttpErrorCode.internalServerError,
  501: HttpErrorCode.notFound,
  503: HttpErrorCode.serviceUnavailable,
};

const _webSocketErrorCodeMap = {
  1001: WebSocketErrorCode.goingAway,
  1002: WebSocketErrorCode.protocolError,
  1003: WebSocketErrorCode.dataError,
  1006: WebSocketErrorCode.abnormalClose,
  1007: WebSocketErrorCode.badMessageFormat,
  1008: WebSocketErrorCode.policyError,
  1009: WebSocketErrorCode.messageTooBig,
  1010: WebSocketErrorCode.missingExtension,
  1011: WebSocketErrorCode.cantFulfill,
};
