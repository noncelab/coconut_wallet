import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Opens the item menu on hold and keeps that pointer available for dragging.
class HomeItemDraggable extends Draggable<String> {
  const HomeItemDraggable({
    super.key,
    required super.child,
    required super.feedback,
    required this.isArranging,
    required this.onLongPress,
    required this.onPointerDragStart,
    this.canStartDrag,
    super.data,
    super.axis,
    super.childWhenDragging,
    super.feedbackOffset,
    super.dragAnchorStrategy,
    super.affinity,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
    super.onDragEnd,
    super.onDragCompleted,
    super.ignoringFeedbackSemantics,
    super.ignoringFeedbackPointer,
    super.rootOverlay,
    super.hitTestBehavior,
    super.allowedButtonsFilter,
  });

  final bool Function() isArranging;
  final VoidCallback onLongPress;
  final void Function(int pointer) onPointerDragStart;
  final bool Function()? canStartDrag;

  static const double movementAfterHold = 12;

  @override
  MultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) {
    return _HomeItemDragGestureRecognizer(
        isArranging: isArranging,
        onLongPress: onLongPress,
        onPointerDragStart: onPointerDragStart,
        canStartDrag: canStartDrag,
        allowedButtonsFilter: allowedButtonsFilter,
      )
      ..onStart = (position) {
        final drag = onStart(position);
        return drag == null ? null : _HomeItemDrag(drag, position);
      };
  }
}

class _HomeItemDrag extends Drag with WidgetsBindingObserver {
  _HomeItemDrag(this._delegate, this._position) {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_finished) return;
      _firstFrameReady = true;
      _refreshTargets();
      if (_pendingEnd case final details?) _finish(details);
    });
  }

  final Drag _delegate;
  Offset _position;
  bool _finished = false;
  bool _firstFrameReady = false;
  DragEndDetails? _pendingEnd;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) cancel();
  }

  void _refreshTargets() {
    if (_finished) return;
    // Menu removal reaches the render tree on the next frame. Refresh even if
    // the finger stays still so the dismissed overlay cannot swallow the drop.
    _delegate.update(DragUpdateDetails(delta: Offset.zero, globalPosition: _position));
  }

  @override
  void update(DragUpdateDetails details) {
    if (_finished) return;
    _position += details.delta;
    _delegate.update(details);
  }

  @override
  void end(DragEndDetails details) {
    if (_finished) return;
    if (!_firstFrameReady) {
      _pendingEnd = details;
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    _refreshTargets();
    _finish(details);
  }

  void _finish(DragEndDetails details) {
    _finished = true;
    _pendingEnd = null;
    WidgetsBinding.instance.removeObserver(this);
    _delegate.end(details);
  }

  @override
  void cancel() {
    if (_finished) return;
    _finished = true;
    _pendingEnd = null;
    WidgetsBinding.instance.removeObserver(this);
    _delegate.cancel();
  }
}

class _HomeItemDragGestureRecognizer extends MultiDragGestureRecognizer with WidgetsBindingObserver {
  _HomeItemDragGestureRecognizer({
    required this.isArranging,
    required this.onLongPress,
    required this.onPointerDragStart,
    required this.canStartDrag,
    super.allowedButtonsFilter,
  }) : super(debugOwner: null) {
    WidgetsBinding.instance.addObserver(this);
  }

  final bool Function() isArranging;
  final VoidCallback onLongPress;
  final void Function(int pointer) onPointerDragStart;
  final bool Function()? canStartDrag;
  final _pointerStates = <int, _HomeItemDragPointerState>{};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    for (final entry in _pointerStates.entries.toList()) {
      entry.value.stopPendingRecognition();
      GestureBinding.instance.cancelPointer(entry.key);
    }
  }

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        (canStartDrag?.call() ?? true) &&
        super.isPointerAllowed(event);
  }

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _pointerStates[event.pointer] = _HomeItemDragPointerState(
      event.position,
      event.kind,
      gestureSettings,
      arranging: isArranging(),
      canStartDrag: canStartDrag,
      onLongPress: () => invokeCallback<void>('onLongPress', onLongPress),
      onDragStart: () => invokeCallback<void>('onPointerDragStart', () => onPointerDragStart(event.pointer)),
      onDispose: () => _pointerStates.remove(event.pointer),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  String get debugDescription => 'home item hold and drag';
}

class _HomeItemDragPointerState extends MultiDragPointerState {
  _HomeItemDragPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings, {
    required this.arranging,
    required this.canStartDrag,
    required this.onLongPress,
    required this.onDragStart,
    required this.onDispose,
  }) {
    if (!arranging) _timer = Timer(kLongPressTimeout, _holdElapsed);
  }

  final bool arranging;
  final bool Function()? canStartDrag;
  final VoidCallback onLongPress;
  final VoidCallback onDragStart;
  final VoidCallback onDispose;
  Timer? _timer;
  GestureMultiDragStartCallback? _starter;
  Offset _holdDelta = Offset.zero;
  bool _holdReady = false;
  bool _menuShown = false;
  bool _aborted = false;

  void stopPendingRecognition() {
    _aborted = true;
    _timer?.cancel();
    _timer = null;
    _starter = null;
  }

  void _holdElapsed() {
    _timer = null;
    if (_aborted || pendingDelta == null) return;
    if (!(canStartDrag?.call() ?? true)) {
      _abort();
      return;
    }
    _holdReady = true;
    _holdDelta = pendingDelta!;
    if (_starter != null) {
      _showMenu();
    } else {
      resolve(GestureDisposition.accepted);
    }
  }

  void _showMenu() {
    if (_menuShown) return;
    _menuShown = true;
    onLongPress();
  }

  void _abort() {
    _aborted = true;
    _timer?.cancel();
    _timer = null;
    resolve(GestureDisposition.rejected);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    if (_aborted) return;
    _starter = starter;
    if (arranging) {
      _startIfMoved();
    } else if (_holdReady) {
      _showMenu();
    }
  }

  @override
  void checkForResolutionAfterMove() {
    if (_aborted) return;
    if (arranging) {
      if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
        if (_starter == null) {
          resolve(GestureDisposition.accepted);
        } else {
          _startIfMoved();
        }
      }
    } else if (!_holdReady) {
      if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) _abort();
    } else {
      _startIfMoved();
    }
  }

  void _startIfMoved() {
    final starter = _starter;
    if (starter == null || pendingDelta == null) return;
    final threshold = arranging ? computeHitSlop(kind, gestureSettings) : HomeItemDraggable.movementAfterHold;
    final movement = arranging ? pendingDelta! : pendingDelta! - _holdDelta;
    if (movement.distance <= threshold) return;
    if (!(canStartDrag?.call() ?? true)) {
      _abort();
      return;
    }
    _starter = null;
    onDragStart();
    starter(initialPosition);
  }

  @override
  void dispose() {
    stopPendingRecognition();
    onDispose();
    super.dispose();
  }
}
