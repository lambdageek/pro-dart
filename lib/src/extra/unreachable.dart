import 'package:meta/meta.dart';

class UnreachableError extends Error {}

@alwaysThrows
T unreachable<T>() {
  assert(false, 'Unreachable code');
  throw UnreachableError();
}
