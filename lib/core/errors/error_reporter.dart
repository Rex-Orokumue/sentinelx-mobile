typedef ErrorSender = Future<void> Function(String message, String? stack, String? route);

/// Reports uncaught errors to the backend. Must never throw or loop: it runs inside error handlers.
class ErrorReporter {
  ErrorReporter(this._send, {this.maxReports = 20});

  final ErrorSender _send;
  final int maxReports;
  int _sent = 0;
  String? _last;

  Future<void> report(Object error, StackTrace? stack, {String? route}) async {
    try {
      final message = error.toString();
      if (_sent >= maxReports || message == _last) return;
      _last = message;
      _sent++;
      await _send(message, stack?.toString(), route);
    } catch (_) {
      // Swallow — a logging failure must never replace one problem with another.
    }
  }
}
