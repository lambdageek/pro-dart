/// Simple processes that work anywhere
library pro.process;

import 'dart:async';
import 'package:meta/meta.dart';
import 'package:pro/pro.dart';

Process yieldingCounter({String name, @required int max}) {
  Stream<Outcome> loop() async* {
    int count = 0;
    while (count < max) {
      print("Counter ($name): $count");
      ++count;
      //yield Outcome.Yielded;
      yield* Process.sleep(Duration(seconds: 1));
    }
    yield Outcome.Finished;
  }

  return Process(loop());
}
