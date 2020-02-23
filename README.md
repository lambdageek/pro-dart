
An exercise in cooperative asynchronous programming.

### Building:

```
pub get
dartanalyzer lib example
```

### Running:

```
dart example/example1.dart
```

or perhaps save some text lines to 'hello.txt' and then

```
dart example/example1.dart < hello.txt
```

### What's here

See [scheduler.dart](lib/src/scheduler.dart) it defines a class
`Scheduler` that executes several `Process` instances in lock-step
round robin fashion.  The processes are cooperative and must
periodically yield back to the scheduler.  Additionally if a process
state indicates that it is blocked, we kick it off the round-robin
queue and into a new `Future` that will wait for the process to signal
that it is ready to run again at which point it goes back on the
queue.
