import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment.dart';
import '../models/user.dart' as models;

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Authenticate a user with email and password.
  Future<models.User?> authenticate({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) return null;
      return _fetchProfile(authUser.id);
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  /// Register a new user with role assignment.
  Future<models.User?> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Registration failed: Unable to create authentication account.');
      }

      final profileResponse = await _client.from('profiles').insert({
        'id': authUser.id,
        'full_name': fullName,
        'email': email,
        'role': role,
      }).select().maybeSingle();

      if (profileResponse == null) {
        throw Exception('Unable to create user profile.');
      }

      return models.User.fromMap(profileResponse as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// Get the currently authenticated user's profile.
  Future<models.User?> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;
      return _fetchProfile(authUser.id);
    } catch (e) {
      throw Exception('Failed to fetch current user: $e');
    }
  }

  /// Fetch a user profile by ID.
  Future<models.User?> _fetchProfile(String id) async {
    try {
      final response =
          await _client.from('profiles').select().eq('id', id).maybeSingle();
      if (response == null) return null;
      return models.User.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Logout the current user.
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Create a new appointment.
  Future<String?> createAppointment(Appointment appointment) async {
    try {
      final response = await _client
          .from('appointments')
          .insert(appointment.toMap())
          .select()
          .maybeSingle();

      if (response == null) return null;
      return (response as Map<String, dynamic>)['id'] as String?;
    } catch (e) {
      throw Exception('Failed to create appointment: $e');
    }
  }

  /// Fetch appointments (all if admin, or filtered by userId if user).
  Future<List<Appointment>> fetchAppointments({String? userId}) async {
    try {
      var query = _client.from('appointments').select();

      if (userId != null) {
        query = query.eq('profile_id', userId);
      }

      final response = await query.order('date_time', ascending: true);
      if (response is! List) return [];

      return response
          .map((map) => Appointment.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch appointments: $e');
    }
  }

  /// Update an appointment's status.
  Future<void> updateAppointmentStatus(String id, String status) async {
    try {
      await _client
          .from('appointments')
          .update({'status': status})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update appointment: $e');
    }
  }

  /// Delete an appointment by ID.
  Future<void> deleteAppointment(String id) async {
    try {
      await _client.from('appointments').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete appointment: $e');
    }
  }
}
