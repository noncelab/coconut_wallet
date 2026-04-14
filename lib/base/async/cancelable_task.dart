class CancelableTask<T> {
  final Future<T> future;
  final Future<void> Function() cancel;

  const CancelableTask({required this.future, required this.cancel});
}

class TaskCancelledException implements Exception {
  const TaskCancelledException();

  @override
  String toString() => 'TaskCancelledException';
}
