import 'dart:async';
import 'process/state.dart';
import 'process/tick.dart';

/// A process does some work, periodically yielding a [Tick] at which point its
/// [Process.state] determines whether it needs to be scheduled again.
abstract class Process {
  State get state;
  Stream<Tick> get stream;
}
