import 'dart:async';
import 'package:meta/meta.dart';
import 'process/outcome.dart';
import 'process.dart';

class _ReadyQueue implements EventSink<ScheduledProcess> {
  Stream<ScheduledProcess> get stream => _controller.stream;
  @override
  void add(ScheduledProcess p) => _controller.add(p);
  @override
  void addError(Object error, [StackTrace stackTrace]) =>
      _controller.addError(error, stackTrace);
  @override
  void close() => _controller.close();

  final StreamController<ScheduledProcess> _controller;

  _ReadyQueue() : _controller = StreamController<ScheduledProcess>();
}

/// A scheduler supervises several processes and periodically allows them to run
///
class Scheduler {
  /// A queue of processes that are ready to run.  It is assumed that for every
  /// scheduled process `p`, `p.subscription` is paused.  When a process yields
  /// [Outcome.Finished] it is removed from the queue; when a process yields
  /// [Outcome.Blocking], it is removed from the queue and a new Future is
  /// scheduled to do the blocking operation, and then to put the process back
  /// in the ready queue.  Otherwise if the process sends [Outcome.Yielded], it
  /// is put back into the queue.  When every process is finished, the queue is
  /// closed and the [dispatch] loop ends.
  final _ReadyQueue ready;

  /// Every process that this scheduler is responsible for.  The dispatcher
  /// is done, when every process yieldd [Outcome.Finished]
  Iterator<ScheduledProcess> get everyProcess => _processes.iterator;

  final List<ScheduledProcess> _processes;

  int _dead;

  Scheduler()
      : ready = _ReadyQueue(),
        _processes = [],
        _dead = 0;

  int get dead => _dead;
  int get numProcesses => _processes.length;

  /// Starts a new process in this scheduler.
  ///
  /// The scheduler will continue dispatching until all the spawned processes are dead.
  void spawn(Process process, [String name]) {
    name ??= process.toString();
    var sp = ScheduledProcess(name, process);
    _processes.add(sp);
    ready.add(sp);
  }

  void spawnStream(Stream<Outcome> stream, [String name]) =>
      spawn(Process(stream), name);

  /// Run the event loop until all the processes are dead.
  ///
  /// If the processes deadlock, this [dispatch] will hang.
  Future<void> dispatch() async {
    await for (final p in ready.stream) {
      print('process ${p.name}, ready to run');
      final outcome = await p.run('run');
      _processOutcome(p, outcome);
      print(
          'end of scheduler iteration: dead = $dead, numProcesses = $numProcesses');
    }
  }

  void _onDead(ScheduledProcess p) {
    p.close();
    _dead++;
    if (dead == numProcesses) {
      ready.close();
    }
  }

  void _processOutcome(ScheduledProcess p, Outcome outcome) {
    print('process ${p.name} ran, outcome was $outcome');
    switch (outcome) {
      case Outcome.Finished:
        _onDead(p);
        break;
      case Outcome.Yielded:
        ready.add(p);
        break;
      case Outcome.Blocking:
        p.doBlocking().then((Outcome blockingOutcome) {
          _processOutcome(p, blockingOutcome);
        });
        break;
    }
  }
}

/// A [ScheduledProcess] is owned by a scheduler and has a subscription to the
/// stream of the underlying process.  The ScheduledProcess resumes the
/// subscription when the process is running and pauses it when the process is
/// to be suspended.  When a process is blocking, the
/// [ScheduledProcess.doBlocking] method kicks off an asynchronous task that
/// will wait to receive a tick from the process when it is no longer blocking
/// and then add it back to the scheduler's ready queue.
@immutable
@sealed
class ScheduledProcess {
  final String name;
  final Process process;
  final StreamSubscription<Outcome> subscription;

  ScheduledProcess(this.name, this.process)
      : subscription = process.stream.listen(null)..pause();

  /// Resume the process until it produces the next outcome, then pause it again
  Future<Outcome> run(String place) {
    final step = Completer<Outcome>();
    subscription
      ..onDone(() {
        print('$place: done $name');
        step.complete(Outcome.Finished);
      })
      ..onData(step.complete)
      ..resume();
    print('$place: resumed $name');
    return step.future.then((tick) {
      subscription.pause();
      print('$place: paused $name');
      return tick;
    });
  }

  void close() {
    subscription.cancel();
  }

  /// Run the process for one step (which is presumably going to block)
  /// asynchronously in a separate future.
  Future<Outcome> doBlocking() {
    return Future(() {
      return run('blocking');
    });
  }
}
