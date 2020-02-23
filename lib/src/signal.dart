import 'dart:async';

/// A [Signal<T>] is like a `Completer<T>` except it's ok to call [Signal.signal] multiple times before the future is acted on.
/// The second and subsequent signals are ignored.
class Signal<T> {
  Completer<T> _completer;
  bool _alreadySignaled;

  Signal()
      : _alreadySignaled = false,
        _completer = Completer<T>();

  /// Reinitialize the Signal and prepare a new uncompleted [future]
  void reset() {
    _alreadySignaled = false;
    _completer = Completer<T>();
  }

  void signal([T value]) {
    if (!_alreadySignaled) {
      _alreadySignaled = true;
      _completer.complete(value);
    }
  }

  T _resetAndReturn(T value) {
    reset();
    return value;
  }

  /// When at least one [signal()] is received, the future completes with the first value and is [reset()].
  Future<T> get future => _completer.future.then(_resetAndReturn);
}
