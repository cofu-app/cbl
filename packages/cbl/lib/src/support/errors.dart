import 'package:cbl_ffi/cbl_ffi.dart';

import '../errors.dart';

extension CBLErrorExceptionExt on CBLErrorException {
  CouchbaseLiteException toCouchbaseLiteException() =>
      _toCouchbaseLiteException(this);
}

T runWithErrorTranslation<T>(T Function() fn) {
  try {
    return fn();
  } on CBLErrorException catch (e) {
    throw _toCouchbaseLiteException(e);
  }
}

CouchbaseLiteException _toCouchbaseLiteException(CBLErrorException exception) {
  switch (exception.domain) {
    case CBLErrorDomain.couchbaseLite:
      return DatabaseException(
        exception.message,
        (exception.code as CBLErrorCode).toDatabaseErrorCode(),
        errorPosition: exception.errorPosition,
        queryString: exception.errorSource,
      );
    case CBLErrorDomain.posix:
      return DatabaseException(
        'errno ${exception.code}: ${exception.message}',
        DatabaseErrorCode.unexpectedError,
      );
    case CBLErrorDomain.sqLite:
      return DatabaseException(
        'SQLite error code ${exception.code}: ${exception.message}',
        DatabaseErrorCode.unexpectedError,
      );
    case CBLErrorDomain.fleece:
      return InvalidJsonException(exception.message);
    case CBLErrorDomain.network:
      return NetworkException(
        exception.message,
        (exception.code as CBLNetworkErrorCode).toNetworkErrorCode(),
      );
    case CBLErrorDomain.webSocket:
      String formatMessage(Object? enumCode) => enumCode != null
          ? exception.message
          : '${exception.message} (${exception.code})';

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