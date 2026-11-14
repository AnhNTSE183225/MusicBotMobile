import 'dart:developer' as dev;
import 'package:logging/logging.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger('MusicBotMobile');
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      dev.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  static void fsmTransition({
    required String entityId,
    required String fromState,
    required String toState,
    required String reason,
  }) {
    final msg = '[FSM] Entity $entityId: $fromState -> $toState (Reason: $reason)';
    dev.log(msg, name: 'state_machine');
    _logger.info(msg);
  }

  static void info(String message) => _logger.info(message);

  static void warning(String message, [Object? error]) =>
      _logger.warning(message, error);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
