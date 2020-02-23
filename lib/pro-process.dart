import 'dart:async';
import 'package:meta/meta.dart';
import 'package:pro/pro.dart';

@sealed
class YieldingCounter implements Process {
  YieldingCounter(this.name, this.max) : _state = State.Running;

  @override
  State get state => _state;

  @override
  Stream<Tick> get stream {
    _stream ??= initStream();
    return _stream;
  }

  Stream<Tick> _stream;
  State _state;

  int max;
  String name;

  Stream<Tick> initStream() async* {
    int count = 0;

    while (count < max) {
      print("Counter ($name): $count");
      ++count;
      _state = State.Running;
      yield Tick.Tock;
    }
    _state = State.Dead;
    yield Tick.Tock;
  }
}
