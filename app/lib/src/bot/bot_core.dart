import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:better_mcfallout_bot/src/better_mcfallout_bot.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

BotCore? _instance;
Logger _logger = Logger('bot_core');

class BotCore {
  static BotCore? get instance {
    return _instance;
  }

  final String host;
  final int port;
  final String email;
  final String password;

  late Process process;
  late Stream<IEvent> eventStream;
  late ConnectedEvent connectedData;
  bool connected = false;

  BotCore.createBot({
    required this.host,
    required this.port,
    required this.email,
    required this.password,
  }) {
    _instance = this;
  }

  Future<bool> connect() async {
    if (connected) return true;
    try {
      await _connect().timeout(const Duration(seconds: 20));
      _logging();
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (!connected) return;
    _executeAction(const BotAction(action: BotActionType.disconnect));
    process.kill();
    connected = false;
  }

  whenEvent<E extends IEvent>(void Function(E event) callback) {
    eventStream.listen((event) {
      if (event is E) {
        callback(event);
      }
    });
  }

  Stream<E> whenEventStream<E extends IEvent>() {
    return Stream.multi((controller) {
      whenEvent<E>((event) {
        controller.add(event);
      });
    });
  }

  void runCommand(String command) {
    if (!connected) return;
    _executeAction(BotAction(
        action: BotActionType.command, argument: {'command': command}));
  }

  void updateConfig() {
    if (!connected) return;
    _executeAction(BotAction(
        action: BotActionType.updateConfig,
        argument: {'config': _getConfig()}));
  }

  Future<void> _connect() async {
    final config = _getConfig();

    process = await Process.start(_getExecutablePath(), [json.encode(config)]);
    eventStream = _listen();

    whenEvent<ConnectedEvent>((event) {
      connected = true;
      connectedData = event;
      _logger.info('Connected to $host:$port');
    });

    // Wait for connecting to the server
    while (!connected) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Stream<IEvent> _listen() {
    late final StreamController<IEvent> controller;

    final stdout = process.stdout.listen((data) {
      try {
        final List<String> jsonList =
            const LineSplitter().convert(utf8.decode(data));

        for (final String json in jsonList) {
          if (json.isEmpty) return;
          final RawEvent event = RawEvent.fromJson(json);

          final handledEvent = _eventHandler(event);
          if (handledEvent != null) {
            controller.add(handledEvent);
          }
        }
      } catch (e) {
        _logger.warning('Failed to parse event: $e');
      }
    });

    controller = StreamController<IEvent>(
      onCancel: () => stdout.cancel(),
      onResume: () => stdout.resume(),
      onPause: () => stdout.pause(),
    );

    process.stderr.listen((data) {
      final String error = utf8.decode(data);
      _logger.severe(error, null, StackTrace.current);
    });

    return controller.stream.asBroadcastStream();
  }

  IEvent? _eventHandler(RawEvent event) {
    switch (event.event) {
      case EventType.connected:
        return ConnectedEvent(event);
      case EventType.info:
        return InfoLogEvent(event);
      case EventType.warn:
        return WarnLogEvent(event);
      case EventType.error:
        return ErrorLogEvent(event);
      case EventType.gameMessage:
        return GameMessageEvent(event);
      case EventType.status:
        return StatusEvent(event);
      default:
        _logger.warning('Unknown event: ${event.event}');
        return null;
    }
  }

  void _executeAction(BotAction action) {
    process.stdin.writeln(json.encode(action.toMap()));
  }

  void _logging() {
    whenEvent<InfoLogEvent>((event) {
      _logger.info(event.message);
    });

    whenEvent<WarnLogEvent>((event) {
      _logger.warning(event.message);
    });

    whenEvent<ErrorLogEvent>((event) {
      _logger.severe(event.message);
    });
  }

  Map _getConfig() => {
        'host': host,
        'port': port,
        'email': email,
        'password': password,
        'autoEat': appConfig.autoEat,
        'autoThrow': appConfig.autoThrow,
        'autoReconnect': appConfig.autoReconnect,
      };

  String _getExecutablePath() {
    final String path;
    if (kReleaseMode) {
      path = join(dirname(Platform.resolvedExecutable), 'lib',
          'better-mcfallout-bot-core');
    } else {
      path = join(dirname(Directory.current.path), 'core', 'out',
          'better-mcfallout-bot');
    }

    return path;
  }
}
