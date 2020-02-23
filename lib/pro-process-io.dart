/// Library combinators that work in command-line and server apps
library pro.process.io;

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'package:pro/pro.dart';

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
      print('Running: have $line');
      yield Outcome.Blocking;
    }
    yield Outcome.Finished;
  }

  return Process(loop());
}

