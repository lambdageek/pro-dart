import 'dart:async';
import 'package:meta/meta.dart';
import 'process/outcome.dart';

/// A process does some work, periodically yielding an [Outcome] which
/// determines whether it needs to be scheduled again.
///
/// The scheduler will pause and resume the stream subscription, so this really
/// only makes sense for non-broadcast streams.
///
/// There are two approaches to defining a new process:
/// 1. Use the [Process.Process] factory constructor that takes a `Stream<Outcome>` argument.
///    This is generally more concise and a good way to go if the state of the
///    process is contained in its closure.
/// 2. Create a new class that `implements` the [Process] interface.
abstract class Process {
  Stream<Outcome> get stream;

  /// Constructs a Process from a stream of outcomes
  factory Process(Stream<Outcome> stream) => _StreamProcess(stream);
}

@sealed
@immutable
class _StreamProcess implements Process {
  _StreamProcess(this._stream);

  final Stream<Outcome> _stream;

  Stream<Outcome> get stream => _stream;
}
