class LogFilter {
  final List<String> _secrets = [];

  void registerSecret(String secret) {
    if (secret.isNotEmpty && !_secrets.contains(secret)) {
      _secrets.add(secret);
    }
  }

  void removeSecret(String secret) {
    _secrets.remove(secret);
  }

  String sanitize(String log) {
    String sanitized = log;
    for (final secret in _secrets) {
      if (secret.length > 4) {
        final masked = '${'*' * (secret.length - 4)}${secret.substring(secret.length - 4)}';
        sanitized = sanitized.replaceAll(secret, masked);
      } else {
        sanitized = sanitized.replaceAll(secret, '****');
      }
    }
    return sanitized;
  }
}

// Global log filter instance
final globalLogFilter = LogFilter();
