import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'package:meta/meta.dart';
import 'package:pro/pro.dart';
import 'package:pro/pro-process.dart';

@sealed
class LineEchoProcess implements Process {
  LineEchoProcess() : _state = State.Running;

  @override
  State get state => _state;

  @override
  Stream<Tick> get stream {
    _stream ??= initStream();
    return _stream;
  }

  Stream<Tick> _stream;
  State _state;

  Stream<Tick> initStream() async* {
    final stdinLines = io.stdin
        .transform(convert.utf8.decoder)
        .transform(const convert.LineSplitter());

    _state = State.Blocked;
    yield Tick.Tock;
    await for (var line in stdinLines) {
      _state = State.Running;
      yield Tick.Tock;
      print("Running: have $line");
      _state = State.Blocked;
      yield Tick.Tock;
    }
    _state = State.Dead;
    yield Tick.Tock;
  }
}

void runner() async {
  print("hello world!\n");

  var scheduler = new Scheduler();

  scheduler.spawn("echo", new LineEchoProcess());
  scheduler.spawn("count a", new YieldingCounter('a', 10));
  scheduler.spawn("count b", new YieldingCounter('b', 10));

  await scheduler.dispatch();
}
