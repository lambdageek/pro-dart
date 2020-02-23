import 'package:pro/pro.dart';
import 'package:pro/pro-process.dart';
import 'package:pro/pro-process-io.dart';

void main() {
  runner();
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
