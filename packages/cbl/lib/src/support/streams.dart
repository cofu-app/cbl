import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'async_callback.dart';
import 'native_object.dart';
import 'resource.dart';

/// A template for creating a [StreamController] which is as [ClosableResource].
abstract class ClosableResourceStreamController<T> with ClosableResourceMixin {
  ClosableResourceStreamController({required this.parent});

  /// The parent resources of this stream controller.
  final AbstractResource parent;

  @protected
  late final StreamController<T> controller = StreamController(
    onListen: () {
      parent.registerChildResource(this);
      use(onListen);
    },
    onPause: onPause,
    onResume: onResume,
    onCancel: onCancel,
  );

  /// The stream this stream controller is controlling.
  Stream<T> get stream => controller.stream;

  /// Must be implemented by subclasses to start the stream.
  @protected
  FutureOr<void> onListen();

  /// May be implemented by subclasses to pause the stream.
  @protected
  void onPause() {}

  /// May be implemented by subclasses to resume the stream.
  @protected
  void onResume() {}

  /// May be implemented by subclasses to cancel the stream.
  @protected
  FutureOr<void> onCancel() {}

  @override
  Future<void> performClose() => controller.close();
}

/// A [Stream] controller to create a [Stream] from a [AsyncCallback].
class CallbackStreamController<T, S>
    extends ClosableResourceStreamController<T> {
  /// Creates a [Stream] controller to create a [Stream] from a
  /// [AsyncCallback].
  ///
  /// Callbacks need to be registered with native code in [startStream].
  ///
  /// [createEvent] receives the result of the callback registration request and
  /// the arguments from the native side and turns them into an event of type
  /// [T].
  ///
  /// The returned stream is single subscription.
  CallbackStreamController({
    required AbstractResource parent,
    required this.startStream,
    required this.createEvent,
  }) : super(parent: parent);

  final S Function(AsyncCallback callback) startStream;
  final FutureOr<T> Function(S registrationResult, List arguments) createEvent;

  late AsyncCallback _callback;
  late Future<bool> _callbackRegistered;
  late S _registrationResult;
  var _canceled = false;

  @override
  Future<void> onListen() async {
    final callbackRegistered = Completer<bool>();
    _callbackRegistered = callbackRegistered.future;

    _callback = AsyncCallback((arguments) async {
      try {
        // Callbacks can come in before the registration request from the
        // worker comes back. In this case `registrationResult` has not be
        // initialized yet. By waiting for `callbackRegistered`,
        // `registrationResult` is guarantied to be set after this line.
        await _callbackRegistered;

        if (_canceled) return;
        final event = await createEvent(_registrationResult, arguments);
        if (_canceled) return;
        controller.add(event);
      } catch (error, stackTrace) {
        if (_canceled) return;
        controller.addError(error, stackTrace);
      }
    }, debugName: 'Stream<$T>');

    try {
      _registrationResult = runKeepAlive(() => startStream(_callback));
      callbackRegistered.complete(true);
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      await controller.close();
      callbackRegistered.complete(false);
    }
  }

  @override
  Future<void> onCancel() async {
    _canceled = true;
    if (await _callbackRegistered) {
      _callback.close();
    }
  }
}

StreamController<T> callbackBroadcastStreamController<T>({
  required void Function(AsyncCallback callback) startStream,
  required T Function(List arguments) createEvent,
}) {
  late AsyncCallback callback;
  late StreamController<T> controller;
  var canceled = false;

  void onListen() {
    canceled = false;

    callback = AsyncCallback((arguments) {
      if (canceled) return;
      try {
        final event = createEvent(arguments);
        controller.add(event);
      } catch (error, stacktrace) {
        controller.addError(error, stacktrace);
      }
    }, debugName: 'Stream<$T>.broadcast');

    startStream(callback);
  }

  void onCancel() {
    canceled = true;
    callback.close();
  }

  return controller =
      StreamController.broadcast(onListen: onListen, onCancel: onCancel);
}

Stream<T> changeStreamWithInitialValue<T>({
  required FutureOr<T> Function() createInitialValue,
  required Stream<T> Function() createChangeStream,
}) {
  late final StreamController<T> controller;
  late final StreamSubscription<T> sub;
  T? initialValue;
  T? firstStreamEvent;
  var streamIsDone = false;
  var subIsCanceled = false;

  void onListen() {
    sub = createChangeStream().listen(
      (event) {
        firstStreamEvent ??= event;
        if (event == firstStreamEvent && firstStreamEvent == initialValue) {
          return;
        }
        controller.add(event);
      },
      onError: controller.addError,
      onDone: () {
        streamIsDone = true;
        controller.close();
      },
    );

    Future(createInitialValue).then(
      (value) {
        if (!streamIsDone && !subIsCanceled && firstStreamEvent == null) {
          initialValue = value;
          controller.add(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!streamIsDone && !subIsCanceled) {
          controller.addError(error, stackTrace);
        }
      },
    );
  }

  Future<void> onCancel() {
    subIsCanceled = true;
    return sub.cancel();
  }

  void onPause() => sub.pause();

  void onResume() => sub.resume();

  controller = StreamController(
    onListen: onListen,
    onCancel: onCancel,
    onPause: onPause,
    onResume: onResume,
  );

  return controller.stream;
}

Future<Uint8List> byteStreamToFuture(Stream<Uint8List> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.toBytes();
}
