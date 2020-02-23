/// Library combinators that work in command-line and server apps
library pro.process.io;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'package:pro/pro.dart';
import 'package:pro/pro-process.dart';

/// A [Process] that reads lines from [io.stdin] and prints them out
///
Process lineEchoProcess() {
  Stream<Outcome> loop() async* {
    final stdinLines = io.stdin
        .transform(convert.utf8.decoder)
        .transform(const convert.LineSplitter());

    yield Outcome.Blocking;
    await for (var line in stdinLines) {
      yield Outcome.Yielded;
      print("Running: have $line");
      yield Outcome.Blocking;
    }
    yield Outcome.Finished;
  }

  return Process(loop());
}

/// An example that creates a [Scheduler], a [lineEchoProcess] and two
/// [yieldingCounter] processes.
void runner() async {
  print("hello world!\n");

  var scheduler = Scheduler();

  scheduler.spawn(lineEchoProcess(), "echo");
  scheduler.spawn(yieldingCounter(name: 'a', max: 10), "count a");
  scheduler.spawn(yieldingCounter(name: 'b', max: 10), "count b");

  await scheduler.dispatch();
}
