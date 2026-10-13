/// Local field feedback only. Future server validation remains authoritative.
abstract final class AuthValidators {
  static String? fullName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter your full name.' : null;

  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? loginPassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  static String? newPassword(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter a password.';
    if (value!.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? confirmation(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Confirm your password.';
    return value == password ? null : 'Passwords do not match.';
  }
}
