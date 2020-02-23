import 'dart:async';
import 'dart:collection';
import 'package:meta/meta.dart';
import 'process/outcome.dart';
import 'process.dart';
import 'pause.dart';
import 'signal.dart';

/// A scheduler supervises several processes and periodically allows them to run
///
class Scheduler {
  /// A queue of processes that are ready to run.  It is assumed that for every
  /// scheduled process `p`, `p.subscription` is paused.  When a process yields
  /// [Outcome.Finished] it is removed from the queue; when a process yields
  /// [Outcome.Blocking], it is removed from the queue and a new microtask is
  /// scheduled to do the blocking operation, and then to put the process back
  /// in the ready queue.
  final Queue<ScheduledProcess> ready;

  /// Every process that this scheduler is responsible for.  The dispatcher
  /// is done, when every process yieldd [Outcome.Finished]
  Iterator<ScheduledProcess> get everyProcess => _processes.iterator;

  List<ScheduledProcess> _processes;

  int _dead;

  Scheduler()
      : ready = Queue<ScheduledProcess>(),
        _processes = [],
        _dead = 0,
        blockedStateChange = Signal();

  int get dead => _dead;
  int get numProcesses => _processes.length;

  /// Starts a new process in this scheduler.
  ///
  /// The scheduler will continue dispatching until all the spawned processes are dead.
  void spawn(Process process, [String name]) {
    name ??= process.toString();
    var sp = ScheduledProcess(name, process);
    _processes.add(sp);
    ready.addLast(sp);
  }

  void spawnStream(Stream<Outcome> stream, [String name]) {
    spawn(Process(stream), name);
  }

  /// Used by blocking processes to signal the dispatcher when they put themselves back in the [ready] queue.
  ///
  /// The dispatcher awaits this signal when the [ready] queue is empty, but not [everyProcess] is dead.
  final Signal<void> blockedStateChange;

  /// Run the event loop until all the processes are dead.
  ///
  /// If the processes deadlock, this [dispatch] will hang.
  void dispatch() async {
    while (dead < numProcesses) {
      while (ready.isEmpty) {
        // forget any notifications that happned while during the previous loop iteration.
        blockedStateChange.reset();
        print("ready is empty");
        await blockedStateChange.future;
        if (dead == numProcesses) {
          print("all processes dead, returning");
          return;
        }
      }

      final p = ready.removeFirst();
      print("process ${p.name}, ready to run");
      final outcome = await p.run("run");
      _processOutcome(p, outcome);
      final readyState = ready.isEmpty ? "empty" : "not empty";
      print(
          "end of scheduler iteration: dead = $dead, ready = $readyState, numProcesses = $numProcesses");
      await pause();
    }
  }

  void _processOutcome(ScheduledProcess p, Outcome outcome) {
    print("process ${p.name} ran, outcome was $outcome");
    switch (outcome) {
      case Outcome.Finished:
        p.close();
        _dead++;
        break;
      case Outcome.Yielded:
        ready.addLast(p);
        break;
      case Outcome.Blocking:
        p.doBlocking().then((Outcome blockingOutcome) {
          blockedStateChange.signal();
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
    Completer<Outcome> step = Completer<Outcome>();
    subscription
      ..onDone(() {
        print("$place: done $name");
        step.complete(Outcome.Finished);
      })
      ..onData(step.complete)
      ..resume();
    print("$place: resumed $name");
    return step.future.then((tick) {
      subscription.pause();
      print("$place: paused $name");
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
      return run("blocking");
    });
  }
}
