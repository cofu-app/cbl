// ignore: lines_longer_than_80_chars
// ignore_for_file: avoid_types_on_closure_parameters,prefer_constructors_over_static_methods,prefer_void_to_null

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cbl/cbl.dart';
import 'package:cbl/src/service/channel.dart';
import 'package:cbl/src/service/serialization/isolate_packet_codec.dart';
import 'package:cbl/src/service/serialization/json_packet_codec.dart';
import 'package:cbl/src/service/serialization/serialization.dart';
import 'package:cbl/src/service/serialization/serialization_codec.dart';
import 'package:cbl/src/support/utils.dart';
import 'package:cbl_ffi/cbl_ffi.dart'
    show Data, DataSliceResultExt, DataTypedListExt;
import 'package:meta/meta.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../test_binding_impl.dart';
import '../test_binding.dart';

void main() {
  setupTestBinding();

  group('Channel', () {
    matrixTest('call with normal return', (channel) async {
      expect(
        channel.call(EchoRequest('Hello')),
        completion('Input: Hello'),
      );
    });

    matrixTest('call with exceptional return', (channel) async {
      expect(
        channel.call(ThrowTestError()),
        throwsA(const TestError('Oops')),
      );
    });

    matrixTest('call with data in request and response', (channel) async {
      Future<void> expectData(Data input, Object output) => expectLater(
            channel
                .call(DataRequest(input))
                .then((value) => value.toTypedList()),
            completion(output),
          );
      final input = Uint8List.fromList([0, 1]).toData();

      // Send Dart typed data
      await expectData(input, [42, 1]);

      // Send `SliceResult`
      await expectData(input.toSliceResult().toData(), [42, 1]);
    });

    matrixTest('call non-existent endpoint', (channel) async {
      expect(
        channel.call(NonExistentEndpoint()),
        throwsA(isA<UnimplementedError>().having(
          (it) => it.message,
          'message',
          'No call handler registered for endpoint: NonExistentEndpoint',
        )),
      );
    });

    matrixTest('stream emits event', (channel) async {
      expect(
        channel.stream(EchoRequest('Hello')),
        emitsInOrder(<Object>[
          'Input: Hello',
          emitsDone,
        ]),
      );
    });

    matrixTest('stream emits error', (channel) async {
      expect(
        channel.stream(ThrowTestError()),
        emitsInOrder(<Object>[
          emitsError(const TestError('Oops')),
          emitsDone,
        ]),
      );
    });

    matrixTest('close infinite stream', (channel) async {
      expect(
        channel.stream(InfiniteStream()),
        emits(null),
      );
    });

    matrixTest('list to stream of non-existente endpoint', (channel) async {
      expect(
        channel.stream(NonExistentEndpoint()),
        emitsInOrder(<Object>[
          emitsError(isA<UnsupportedError>().having(
            (it) => it.message,
            'message',
            'No stream handler registered for endpoint: NonExistentEndpoint',
          )),
          emitsDone,
        ]),
      );
    });
  });
}

@isTest
void matrixTest(
  String description,
  Future Function(Channel channel) fn,
) {
  void _test(
      ChannelTransport transport, SerializationTarget serializationType) {
    test(
      '$description (variant: '
      'transport: ${describeEnum(transport)}, '
      // ignore: missing_whitespace_between_adjacent_strings
      'target: ${describeEnum(serializationType)}'
      ')',
      () async {
        StreamChannel<Object?> localTransport;

        switch (transport) {
          case ChannelTransport.controller:
            final controller = StreamChannelController<Object?>();
            localTransport = controller.local;
            final remote = Channel(
              transport: controller.foreign,
              packetCodec: packetCoded(serializationType),
              serializationRegistry: testSerializationRegistry(),
            );
            addTearDown(remote.close);
            registerTestHandlers(remote);
            break;
          case ChannelTransport.isolatPort:
            final receivePort = ReceivePort();
            localTransport = IsolateChannel.connectReceive(receivePort);
            final isolate = await Isolate.spawn(
              testIsolateMain,
              TestIsolateConfig(
                libraries,
                receivePort.sendPort,
                serializationType,
              ),
            );
            addTearDown(isolate.kill);
            break;
          case ChannelTransport.webSocket:
            final httpServer = await HttpServer.bind('127.0.0.1', 0);
            addTearDown(() => httpServer.close(force: true));

            httpServer.transform(WebSocketTransformer()).listen((webSocket) {
              final remote = Channel(
                transport: IOWebSocketChannel(webSocket),
                packetCodec: packetCoded(serializationType),
                serializationRegistry: testSerializationRegistry(),
              );

              registerTestHandlers(remote);
            });

            localTransport =
                IOWebSocketChannel.connect('ws://127.0.0.1:${httpServer.port}');
            break;
        }

        final local = Channel(
          transport: localTransport,
          packetCodec: packetCoded(serializationType),
          serializationRegistry: testSerializationRegistry(),
        );
        addTearDown(local.close);

        await fn(local);
      },
    );
  }

  _test(ChannelTransport.controller, SerializationTarget.isolatePort);
  _test(ChannelTransport.controller, SerializationTarget.json);
  _test(ChannelTransport.isolatPort, SerializationTarget.isolatePort);
  _test(ChannelTransport.isolatPort, SerializationTarget.json);
  _test(ChannelTransport.webSocket, SerializationTarget.json);
}

enum ChannelTransport {
  isolatPort,
  webSocket,
  controller,
}

void registerTestHandlers(Channel channel) {
  channel
    ..addCallEndpoint((EchoRequest req) => 'Input: ${req.input}')
    ..addCallEndpoint((DataRequest req) {
      final result = req.input.toTypedList();
      result[0] = 42;
      return result.toData();
    })
    ..addCallEndpoint((ThrowTestError _) =>
        Future<void>.error(const TestError('Oops'), StackTrace.current))
    ..addStreamEndpoint(
        (EchoRequest req) => Stream.value('Input: ${req.input}'))
    ..addStreamEndpoint((ThrowTestError _) =>
        Stream<void>.error(const TestError('Oops'), StackTrace.current))
    ..addStreamEndpoint((InfiniteStream _) =>
        Stream<void>.periodic(const Duration(milliseconds: 100)));
}

class TestIsolateConfig {
  TestIsolateConfig(
    this.libraries,
    this.sendPort,
    this.target,
  );

  final Libraries libraries;
  final SendPort? sendPort;
  final SerializationTarget target;
}

void testIsolateMain(TestIsolateConfig config) {
  CouchbaseLite.init(libraries: config.libraries);

  final remote = Channel(
    transport: IsolateChannel.connectSend(config.sendPort!),
    autoOpen: false,
    packetCodec: packetCoded(config.target),
    serializationRegistry: testSerializationRegistry(),
  );

  registerTestHandlers(remote);

  remote.open();
}

PacketCodec packetCoded(SerializationTarget target) {
  switch (target) {
    case SerializationTarget.isolatePort:
      return IsolatePacketCodec();
    case SerializationTarget.json:
      return JsonPacketCodec();
  }
}

SerializationRegistry testSerializationRegistry() => SerializationRegistry()
  ..addSerializableCodec('Echo', EchoRequest.deserialize)
  ..addSerializableCodec(
    'Blob',
    DataRequest.deserialize,
    isIsolatePortSafe: false,
  )
  ..addSerializableCodec('ThrowError', ThrowTestError.deserialize)
  ..addSerializableCodec('InfiniteStream', InfiniteStream.deserialize)
  ..addSerializableCodec('NonExistentEndpoint', NonExistentEndpoint.deserialize)
  ..addSerializableCodec('TestError', TestError.deserialize);

class EchoRequest extends Request<String> {
  EchoRequest(this.input);

  final String input;

  @override
  StringMap serialize(SerializationContext context) => {'input': input};

  static EchoRequest deserialize(StringMap map, SerializationContext context) =>
      EchoRequest(map['input']! as String);
}

class DataRequest extends Request<Data> {
  DataRequest(this.input);

  final Data input;

  @override
  StringMap serialize(SerializationContext context) =>
      {'input': context.serialize(input)};

  static DataRequest deserialize(StringMap map, SerializationContext context) =>
      DataRequest(context.deserializeAs(map['input'])!);
}

class ThrowTestError extends Request<Null> {
  @override
  StringMap serialize(SerializationContext context) => {};

  static ThrowTestError deserialize(
          StringMap map, SerializationContext context) =>
      ThrowTestError();
}

class InfiniteStream extends Request<Null> {
  @override
  StringMap serialize(SerializationContext context) => {};

  static InfiniteStream deserialize(
          StringMap map, SerializationContext context) =>
      InfiniteStream();
}

class NonExistentEndpoint extends Request<Null> {
  @override
  StringMap serialize(SerializationContext context) => {};

  static NonExistentEndpoint deserialize(
          StringMap map, SerializationContext context) =>
      NonExistentEndpoint();
}

@immutable
class TestError implements Exception, Serializable {
  const TestError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'TestError: $message';

  @override
  StringMap serialize(SerializationContext context) => {'message': message};

  static TestError deserialize(StringMap map, SerializationContext context) =>
      TestError(map.getAs('message'));
}
