import '../database/database.dart';

/// Helper to get the default/current user ID
class UserSession {
  final AppDatabase _db;

  UserSession(this._db);

  /// Get the first user ID (for now, assuming single user)
  Future<String> getDefaultUserId() async {
    final users = await _db.select(_db.users).get();
    if (users.isEmpty) {
      throw StateError('No users found in database');
    }
    return users.first.id;
  }
}
