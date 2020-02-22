import 'dart:async';
import 'dart:io' as io;
import 'dart:convert' as convert;
import 'dart:collection';
import 'package:meta/meta.dart';

class UnreachableError extends Error {}

@alwaysThrows
T unreachable<T>() {
  assert  (false, "Unreachable code");
  throw new UnreachableError ();
}

/*
@immutable
abstract class State {
  static const Dead = _DeadState ();
  const State._base ();

  T match<T> ({@required T onDead()}) {
    if (this is _DeadState) {
      return onDead ();
    }
    return unreachable();
  }
}

@immutable @sealed
class _DeadState extends State {
  const _DeadState () : super._base();
}
*/

enum State { Dead, Running, Blocked }

enum Tick { Tock }

class Signal {
  Completer<void> _completer;
  bool _alreadySignaled;

  Signal() : _alreadySignaled = false, _completer = Completer<void>();

  void reset () {
    _alreadySignaled = false;
    _completer = Completer<void>();
  }

  void signal () {
    if (!_alreadySignaled) {
      _alreadySignaled = true;
      _completer.complete (null);
    }
  }

  Future<void> get future => _completer.future;
}

/// A scheduler supervises several processes and periodically allows them to run
///
class Scheduler {
  /// A queue of processes that are ready to run.  It is assumed that for every
  /// scheduled process p, p.process.state == [State.Running] and p.subscription
  /// is paused.  When a process is [State.Dead] it is removed from the queue;
  /// when a process is blocked, it is removed from the queue and will be put
  /// back in when it is ready again.
  final Queue<ScheduledProcess>  ready;
  /// Every process that this scheduler is responsible for.  When the dispatcher is done, every subscription
  Iterator<ScheduledProcess> get everyProcess => _processes.iterator;

  List<ScheduledProcess> _processes;
  
  int _dead;

  Scheduler() : ready = Queue<ScheduledProcess>() , _processes = [], _dead = 0, blockedStateChange = Signal();

  int get dead => _dead;
  int get numProcesses => _processes.length;

  void spawn (Process process) {
    var sp = ScheduledProcess (process);
    _processes.add (sp);
    assert (process.state == State.Running);
    ready.addLast (sp);
  }

  Signal blockedStateChange;
  
  void dispatch () async {
    while (dead < numProcesses) {
      while (ready.isEmpty) {
        
        print ("ready is empty");
        await blockedStateChange.future;
        blockedStateChange.reset();
        if (dead == numProcesses) {
          print("all processes dead, returning");
          return;
        }
      }

      final p = ready.removeFirst();
      assert (p.process.state == State.Running);
      await p.run();
      final s = p.process.state;
      print ("process, ran, new state is $s");
      switch (s) {
        case State.Dead:
        p.close();
        _dead++;
        break;
        case State.Running:
        ready.addLast(p);
        break;
        case State.Blocked:
        p.doBlocking (onReady: () { blockedStateChange.signal(); ready.addLast (p); print ("process is ready"); });
        break;
      }
      final readyState = ready.isEmpty ? "empty" : "not empty";
      print ("end of scheduler iteration: dead = $dead, ready = $readyState, numProcesses = $numProcesses");
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
@immutable @sealed
class ScheduledProcess {
  final Process process;
  final StreamSubscription<Tick> subscription;

  ScheduledProcess (this.process) : subscription = process.stream.listen(null)..pause();

  Future<Tick> run () {
    Completer<Tick> step = Completer<Tick> ();
    subscription
    ..onDone (() {
        step.complete (Tick.Tock);
    })
    ..onData ((Tick tick) {
        // FIXME: xxx Is it safe to call pause from an onData handler?
        subscription.pause ();                 
        step.complete (tick);
    })
    ..resume ();
    return step.future;
  }

  void close() {
    subscription.cancel();
  }

  void doBlocking ({@required void onReady()}) {
    void runBlocking () {
      print ("in runBlocking");
      subscription
      ..onDone (() {
          print ("in blocking onDone");
          onReady();
      })
      ..onData ((Tick tick) {
          print ("in blocking onData");
          subscription.pause ();
          onReady();
      })
      ..resume ();
    }

    Timer.run (runBlocking);
  }
}

/// A process does some work, periodically yielding a [Tick] at which point its
/// [Process.state] determines whether it needs to be scheduled again.
abstract class Process {
  State get state;
  Stream<Tick> get stream;
}

/// A (deterministic) automaton takes a state S and an alphabet symbol A and returns a new state
typedef Automaton<S, A> = S Function({@required S state, A symbol});

/// A stream transformer that consumes A stream of alphabet symbols A and
/// returns a stream of automaton states S The first value in the transformed
/// stream will be the initial state, before the first input symbol is consumed.
StreamTransformer<A, S> unfoldAutomaton<S, A>(
    Automaton<S, A> step, S initialState) {
  StreamSubscription<S> onListenTransformer(
      Stream<A> stream, bool cancelOnError) {
    var state = initialState;
    StreamController<S> controller;
    StreamSubscription<A> subscription;

    void startEvents() {
      controller.add(initialState);
      subscription = stream.listen(
          (A evt) {
            try {
              state = step(state: state, symbol: evt);
              controller.add(state);
            } catch (e, s) {
              controller.addError(e, s);
            }
          },
          onError: controller.addError,
          onDone: () {
            controller.close();
          },
          cancelOnError: cancelOnError);
    }

    Future cancelEvents() {
      var toCancel = subscription;
      subscription = null;
      return toCancel.cancel();
    }

    if (stream.isBroadcast) {
      controller = StreamController<S>.broadcast(
          onListen: startEvents, onCancel: cancelEvents);
    } else {
      controller = StreamController<S>(
          onListen: startEvents,
          onPause: ([Future<dynamic> resume]) => subscription.pause(resume),
          onResume: () => subscription.resume(),
          onCancel: cancelEvents);
    }

    return controller.stream.listen(null);
  }

  return StreamTransformer<A, S>(onListenTransformer);
}

@sealed
class LineEchoProcess implements Process {
  LineEchoProcess () : _state = State.Running;

  @override
  State get state => _state;

  @override
  Stream<Tick> get stream { _stream ??= initStream(); return _stream; }

  Stream<Tick> _stream;
  State _state;

  Stream<Tick> initStream () async* {
    final stdinLines = io.stdin.transform (convert.utf8.decoder).transform (const convert.LineSplitter());

    _state = State.Blocked;
    yield Tick.Tock;
    await for (var line in stdinLines) {
      _state = State.Running;
      yield Tick.Tock;
      print ("Running: have $line");
      _state = State.Blocked;
      yield Tick.Tock;
    }
    _state = State.Dead;
    yield Tick.Tock;
  }

}
void runner() async {
  print("hello world!\n");

  /*
  var stream = Stream.periodic(Duration(milliseconds: 250), (_) => Tick.Tock);

  int step({int state, Tick symbol}) {
    return state + 1;
  }

  stream.transform(unfoldAutomaton(step, 0)).take(5).listen(print);
  */

  var scheduler = new Scheduler ();

  scheduler.spawn (new LineEchoProcess());

  await scheduler.dispatch ();

  
}
