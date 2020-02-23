/// Cooperative asynchronous scheduling core library
///
/// Use [Scheduler] to create a new scheduler and [Scheduler.spawn] or
/// [Scheduler.spawnStream] to include a [Process] to be scheduled.  Then wait
/// for [Scheduler.dispatch] to complete when all the processes are
/// [Outcome.Finished]
library pro;

export 'src/signal.dart';
export 'src/pause.dart';
export 'src/process/outcome.dart';
export 'src/process.dart';
export 'src/scheduler.dart';
