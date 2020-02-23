
import 'dart:async';

/// A [Signal] is like a [Completer] except it's ok to call [signal] multiple times before the future is acted on.
/// The second and subsequent signals are ignored.
class Signal {
  Completer<void> _completer;
  bool _alreadySignaled;

  Signal()
      : _alreadySignaled = false,
        _completer = Completer<void>();

  void reset() {
    _alreadySignaled = false;
    _completer = Completer<void>();
  }

  void signal() {
    if (!_alreadySignaled) {
      _alreadySignaled = true;
      _completer.complete(null);
    }
  }

  Future<void> get future => _completer.future.then((_) {
        reset();
      });
}
