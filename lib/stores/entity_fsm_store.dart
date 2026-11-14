import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../core/telemetry/logger.dart';
import '../models/state_machine_dto.dart';

/// Deterministic Finite State Machine (FSM) controller with OS lifecycle reconciliation.
/// Strictly adheres to MOBILE_TECHSTACK.md Section 10 & VIBE_CODING_RULES.md Rule 2.
class StatefulEntityController<T> with WidgetsBindingObserver {
  final String id;
  final Signal<EntityStatus> status = signal(EntityStatus.disconnected);
  final Signal<T?> activeData = signal(null);
  final Signal<String?> errorMessage = signal(null);

  Timer? _progressTicker;
  EntityStatus? _preBackgroundStatus;
  final VoidCallback? onForegroundResync;
  void Function()? _tickerCallback;
  Duration _tickerInterval = const Duration(milliseconds: 100);

  StatefulEntityController({
    required this.id,
    this.onForegroundResync,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  void transitionTo(
    EntityStatus next, {
    required String reason,
    T? data,
    String? error,
  }) {
    final current = status.value;
    if (current == next && data == null && error == null) return;

    batch(() {
      status.value = next;
      if (data != null) {
        activeData.value = data;
      }
      errorMessage.value = error;

      // Invariant enforcement: Atomic teardown on resting or fault states
      if (next == EntityStatus.idle ||
          next == EntityStatus.disconnected ||
          next == EntityStatus.error) {
        _cancelTickers();
        activeData.value = null;
      } else if (next == EntityStatus.paused || next == EntityStatus.loading) {
        _cancelTickers();
      }
    });

    AppLogger.fsmTransition(
      entityId: id,
      fromState: current.name,
      toState: next.name,
      reason: reason,
    );
  }

  void startPeriodicTicker({
    required Duration interval,
    required void Function() onTick,
  }) {
    _tickerInterval = interval;
    _tickerCallback = onTick;
    _cancelTickers();
    if (status.value == EntityStatus.active) {
      _progressTicker = Timer.periodic(interval, (_) => onTick());
    }
  }

  /// Reconciles mobile OS foreground/background transitions deterministically
  @override
  void didChangeAppLifecycleState(AppLifecycleState osState) {
    switch (osState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (status.value == EntityStatus.active) {
          _preBackgroundStatus = EntityStatus.active;
          _cancelTickers();
          AppLogger.fsmTransition(
            entityId: id,
            fromState: status.value.name,
            toState: 'suspended_tickers',
            reason: 'OS ${osState.name}',
          );
        }
        break;
      case AppLifecycleState.resumed:
        if (_preBackgroundStatus == EntityStatus.active) {
          _preBackgroundStatus = null;
          transitionTo(
            EntityStatus.loading,
            reason: 'OS foreground resume resync',
          );
          if (onForegroundResync != null) {
            onForegroundResync!();
          } else if (_tickerCallback != null) {
            startPeriodicTicker(
              interval: _tickerInterval,
              onTick: _tickerCallback!,
            );
          }
        }
        break;
      case AppLifecycleState.detached:
        transitionTo(
          EntityStatus.disconnected,
          reason: 'OS detached engine',
        );
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _cancelTickers() {
    _progressTicker?.cancel();
    _progressTicker = null;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTickers();
    status.dispose();
    activeData.dispose();
    errorMessage.dispose();
  }
}
