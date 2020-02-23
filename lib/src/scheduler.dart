import 'dart:async';
import 'dart:collection';
import 'package:meta/meta.dart';
import 'process/state.dart';
import 'process/tick.dart';
import 'process.dart';
import 'pause.dart';
import 'signal.dart';

/// A scheduler supervises several processes and periodically allows them to run
///
class Scheduler {
  /// A queue of processes that are ready to run.  It is assumed that for every
  /// scheduled process p, p.process.state == [State.Running] and p.subscription
  /// is paused.  When a process is [State.Dead] it is removed from the queue;
  /// when a process is blocked, it is removed from the queue and will be put
  /// back in when it is ready again.
  final Queue<ScheduledProcess> ready;

  /// Every process that this scheduler is responsible for.  When the dispatcher
  /// is done, every process will be in [State.Dead]
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

  void spawn(String name, Process process) {
    var sp = ScheduledProcess(name, process);
    _processes.add(sp);
    assert(process.state == State.Running);
    ready.addLast(sp);
  }

  final Signal blockedStateChange;

  void dispatch() async {
    while (dead < numProcesses) {
      while (ready.isEmpty) {
        print("ready is empty");
        await blockedStateChange.future;
        if (dead == numProcesses) {
          print("all processes dead, returning");
          return;
        }
      }

      final p = ready.removeFirst();
      assert(p.process.state == State.Running);
      final n = p.name;
      print("process $n, ready to run");
      await p.run();
      final s = p.process.state;
      print("process $n ran, new state is $s");
      switch (s) {
        case State.Dead:
          p.close();
          _dead++;
          break;
        case State.Running:
          ready.addLast(p);
          break;
        case State.Blocked:
          p.doBlocking(onReady: () {
            blockedStateChange.signal();
            ready.addLast(p);
            print("process $n is ready");
          });
          break;
      }
      final readyState = ready.isEmpty ? "empty" : "not empty";
      print(
          "end of scheduler iteration: dead = $dead, ready = $readyState, numProcesses = $numProcesses");
      await pause();
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
  final StreamSubscription<Tick> subscription;

  ScheduledProcess(this.name, this.process)
      : subscription = process.stream.listen(null)..pause();

  Future<Tick> run() {
    Completer<Tick> step = Completer<Tick>();
    subscription
      ..onDone(() {
        print("run: done $name");
        step.complete(Tick.Tock);
      })
      ..onData((Tick tick) {
        // FIXME: xxx Is it safe to call pause from an onData handler?
        //subscription.pause ();
        step.complete(tick);
      })
      ..resume();
    print("run: resumed $name");
    return step.future.then((tick) {
      subscription.pause();
      print("run: paused $name");
      return tick;
    });
  }

  void close() {
    subscription.cancel();
  }

  void doBlocking({@required void onReady()}) {
    void runBlocking() {
      print("in runBlocking of $name");
      subscription
        ..onDone(() {
          print("in blocking onDone of $name");
          onReady();
        })
        ..onData((Tick tick) {
          print("in blocking onData of $name");
          subscription.pause();
          onReady();
        })
        ..resume();
    }

    Timer.run(runBlocking);
  }
}
