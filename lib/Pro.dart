import 'dart:async';
import 'package:meta/meta.dart';

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

enum Tick { Tock }

void runner() {
  print("hello world!\n");

  var stream = Stream.periodic(Duration(milliseconds: 250), (_) => Tick.Tock);

  int step({int state, Tick symbol}) {
    return state + 1;
  }

  stream.transform(unfoldAutomaton(step, 0)).take(5).listen(print);
}
