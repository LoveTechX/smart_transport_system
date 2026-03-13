class SecurityService {
  SecurityService._();

  static final Map<String, _AttemptState> _attempts = {};

  static const int _maxAttempts = 5;
  static const Duration _lockDuration = Duration(minutes: 5);

  static String normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  static String normalizePassword(String value) {
    return value.trim();
  }

  static bool isValidEmail(String value) {
    final email = normalizeEmail(value);
    if (email.isEmpty || email.length > 254) {
      return false;
    }

    final emailRegex =
        RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPassword(String value) {
    final password = normalizePassword(value);
    if (password.length < 8 || password.length > 64) {
      return false;
    }

    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  static String passwordPolicyMessage() {
    return 'Password must be 8-64 chars with upper, lower, number, and special symbol.';
  }

  static Duration? getRemainingLock(String key) {
    final state = _attempts[key];
    if (state == null) {
      return null;
    }

    final now = DateTime.now();
    final lockedUntil = state.lockedUntil;

    if (lockedUntil == null || now.isAfter(lockedUntil)) {
      if (lockedUntil != null) {
        _attempts[key] = _AttemptState(count: 0);
      }
      return null;
    }

    return lockedUntil.difference(now);
  }

  static bool canAttempt(String key) {
    return getRemainingLock(key) == null;
  }

  static void registerFailure(String key) {
    final now = DateTime.now();
    final current = _attempts[key] ?? _AttemptState(count: 0);

    final nextCount = current.count + 1;
    DateTime? lockedUntil;

    if (nextCount >= _maxAttempts) {
      lockedUntil = now.add(_lockDuration);
    }

    _attempts[key] = _AttemptState(
      count: nextCount,
      lockedUntil: lockedUntil,
    );
  }

  static void registerSuccess(String key) {
    _attempts[key] = _AttemptState(count: 0);
  }
}

class _AttemptState {
  final int count;
  final DateTime? lockedUntil;

  const _AttemptState({
    required this.count,
    this.lockedUntil,
  });
}
