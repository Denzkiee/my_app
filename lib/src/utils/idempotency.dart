/// Simple idempotency guard to prevent rapid duplicate API calls.
///
/// Tracks a key (e.g. `'sendOtp'`) and only allows the operation
/// to proceed once within [debounceMs] milliseconds.
class IdempotencyGuard {
  IdempotencyGuard._();
  static final IdempotencyGuard instance = IdempotencyGuard._();

  final Map<String, int> _lastRun = {};

  /// Returns `true` if the operation for [key] should be allowed to proceed.
  /// Returns `false` if it was called less than [debounceMs] ms ago.
  bool allow(String key, {int debounceMs = 5000}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastRun[key];
    if (last != null && (now - last) < debounceMs) {
      return false;
    }
    _lastRun[key] = now;
    return true;
  }

  /// Clears the guard for [key] so the next call is allowed.
  void reset(String key) {
    _lastRun.remove(key);
  }

  /// Clears all guards.
  void resetAll() {
    _lastRun.clear();
  }
}

/// Wraps raw exception text into a user-friendly message.
String friendlyError(dynamic error) {
  final msg = error.toString().replaceAll('Exception: ', '');
  // Common Supabase error patterns
  if (msg.contains('email_address_conflict') || msg.contains('already registered') || msg.contains('already exists')) {
    return 'This email address is already registered. Try signing in instead.';
  }
  if (msg.contains('invalid_otp') || msg.contains('Invalid OTP')) {
    return 'The OTP code you entered is invalid or expired. Request a new one.';
  }
  if (msg.contains('expired') || msg.contains('token_exp')) {
    return 'The OTP has expired. Please request a new one.';
  }
  if (msg.contains('rate_limit') || msg.contains('too_many') || msg.contains('429')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (msg.contains('invalid_credentials') || msg.contains('Invalid login')) {
    return 'Invalid email or password. Please check your credentials.';
  }
  if (msg.contains('Password should be')) {
    return msg;
  }
  if (msg.contains('network') || msg.contains('timeout') || msg.contains('Failed host lookup')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  if (msg.length > 120) {
    return 'Something went wrong. Please try again later.';
  }
  return msg;
}