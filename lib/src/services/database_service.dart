import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_log.dart';
import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/clinic_availability.dart';
import '../models/clinic_service.dart';
import '../models/user.dart' as models;

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Auth & profiles
  // ---------------------------------------------------------------------------

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

      await Future.delayed(const Duration(milliseconds: 500));

      dynamic profileResponse;
      var retries = 0;
      const maxRetries = 3;

      while (retries < maxRetries) {
        try {
          profileResponse = await _client.from('profiles').insert({
            'id': authUser.id,
            'full_name': fullName,
            'email': email,
            'role': role,
          }).select().maybeSingle();

          if (profileResponse != null) break;
        } catch (_) {
          retries++;
          if (retries >= maxRetries) rethrow;
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }

      if (profileResponse == null) {
        throw Exception(
          'Unable to create user profile. Please check your email for confirmation and try logging in.',
        );
      }

      final user = models.User.fromMap(profileResponse as Map<String, dynamic>);
      await logActivity(
        action: 'registered',
        entityType: 'profile',
        entityId: user.id,
        details: {'email': email, 'role': role},
      );
      return user;
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  Future<models.User?> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;
      return _fetchProfile(authUser.id);
    } catch (e) {
      throw Exception('Failed to fetch current user: $e');
    }
  }

  Future<models.User?> _fetchProfile(String id) async {
    final response = await _client.from('profiles').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return models.User.fromMap(response as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Activity logs
  // ---------------------------------------------------------------------------

  Future<void> logActivity({
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic> details = const {},
  }) async {
    final user = await getCurrentUser();
    if (user?.id == null) return;

    await _client.from('activity_logs').insert({
      'actor_id': user!.id,
      'actor_role': user.role,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
    });
  }

  Future<List<ActivityLog>> fetchActivityLogs() async {
    final response = await _client
        .from('activity_logs')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(200);

    if (response is! List) return [];
    return response
        .map((map) => ActivityLog.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Clinics
  // ---------------------------------------------------------------------------

  Future<List<Clinic>> fetchApprovedClinics() async {
    final response = await _client
        .from('clinics')
        .select()
        .eq('application_status', 'approved')
        .order('name');

    if (response is! List) return [];
    return response.map((m) => Clinic.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<Clinic>> fetchPendingClinicApplications() async {
    final response = await _client
        .from('clinics')
        .select()
        .eq('application_status', 'pending')
        .order('created_at');

    if (response is! List) return [];
    return response.map((m) => Clinic.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<Clinic?> fetchClinicByOwner(String ownerId) async {
    final response =
        await _client.from('clinics').select().eq('owner_id', ownerId).maybeSingle();
    if (response == null) return null;
    return Clinic.fromMap(response as Map<String, dynamic>);
  }

  Future<Clinic?> fetchClinicById(String clinicId) async {
    final response = await _client.from('clinics').select().eq('id', clinicId).maybeSingle();
    if (response == null) return null;
    return Clinic.fromMap(response as Map<String, dynamic>);
  }

  Future<Clinic> submitClinicApplication({
    required String ownerId,
    required String name,
    required String description,
    required String address,
    required String phone,
    String? existingClinicId,
  }) async {
    final payload = {
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'application_status': 'pending',
      'admin_notes': '',
    };

    Map<String, dynamic> response;
    if (existingClinicId != null) {
      response = await _client
          .from('clinics')
          .update(payload)
          .eq('id', existingClinicId)
          .select()
          .single() as Map<String, dynamic>;
    } else {
      response = await _client.from('clinics').insert(payload).select().single()
          as Map<String, dynamic>;
    }

    final clinic = Clinic.fromMap(response);
    await logActivity(
      action: existingClinicId != null ? 'resubmitted_clinic_application' : 'submitted_clinic_application',
      entityType: 'clinic',
      entityId: clinic.id,
      details: {'name': name},
    );
    return clinic;
  }

  Future<Clinic> reviewClinicApplication({
    required String clinicId,
    required bool approved,
    String adminNotes = '',
  }) async {
    final response = await _client
        .from('clinics')
        .update({
          'application_status': approved ? 'approved' : 'rejected',
          'admin_notes': adminNotes,
        })
        .eq('id', clinicId)
        .select()
        .single() as Map<String, dynamic>;

    final clinic = Clinic.fromMap(response);
    await logActivity(
      action: approved ? 'approved_clinic' : 'rejected_clinic',
      entityType: 'clinic',
      entityId: clinicId,
      details: {'name': clinic.name, 'admin_notes': adminNotes},
    );
    return clinic;
  }

  Future<Clinic> updateClinicDetails({
    required String clinicId,
    required String name,
    required String description,
    required String address,
    required String phone,
  }) async {
    final response = await _client
        .from('clinics')
        .update({
          'name': name,
          'description': description,
          'address': address,
          'phone': phone,
        })
        .eq('id', clinicId)
        .select()
        .single() as Map<String, dynamic>;

    final clinic = Clinic.fromMap(response);
    await logActivity(
      action: 'updated_clinic_details',
      entityType: 'clinic',
      entityId: clinicId,
      details: {'name': name},
    );
    return clinic;
  }

  // ---------------------------------------------------------------------------
  // Clinic services
  // ---------------------------------------------------------------------------

  Future<List<ClinicService>> fetchClinicServices(String clinicId) async {
    final response = await _client
        .from('clinic_services')
        .select()
        .eq('clinic_id', clinicId)
        .order('name');

    if (response is! List) return [];
    return response.map((m) => ClinicService.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<ClinicService> addClinicService({
    required String clinicId,
    required String name,
    String description = '',
  }) async {
    final response = await _client
        .from('clinic_services')
        .insert({
          'clinic_id': clinicId,
          'name': name,
          'description': description,
        })
        .select()
        .single() as Map<String, dynamic>;

    final service = ClinicService.fromMap(response);
    await logActivity(
      action: 'added_service',
      entityType: 'clinic_service',
      entityId: service.id,
      details: {'clinic_id': clinicId, 'name': name},
    );
    return service;
  }

  Future<void> deleteClinicService(String serviceId) async {
    await _client.from('clinic_services').delete().eq('id', serviceId);
    await logActivity(
      action: 'deleted_service',
      entityType: 'clinic_service',
      entityId: serviceId,
    );
  }

  // ---------------------------------------------------------------------------
  // Clinic availability
  // ---------------------------------------------------------------------------

  Future<List<ClinicAvailability>> fetchClinicAvailability(String clinicId) async {
    final response = await _client
        .from('clinic_availability')
        .select()
        .eq('clinic_id', clinicId)
        .order('day_of_week')
        .order('start_time');

    if (response is! List) return [];
    return response
        .map((m) => ClinicAvailability.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<ClinicAvailability> addClinicAvailability({
    required String clinicId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
  }) async {
    final response = await _client
        .from('clinic_availability')
        .insert({
          'clinic_id': clinicId,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'slot_duration_minutes': slotDurationMinutes,
        })
        .select()
        .single() as Map<String, dynamic>;

    final slot = ClinicAvailability.fromMap(response);
    await logActivity(
      action: 'added_availability',
      entityType: 'clinic_availability',
      entityId: slot.id,
      details: {
        'clinic_id': clinicId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      },
    );
    return slot;
  }

  Future<void> deleteClinicAvailability(String availabilityId) async {
    await _client.from('clinic_availability').delete().eq('id', availabilityId);
    await logActivity(
      action: 'deleted_availability',
      entityType: 'clinic_availability',
      entityId: availabilityId,
    );
  }

  // ---------------------------------------------------------------------------
  // Appointments
  // ---------------------------------------------------------------------------

  Future<String?> createAppointment(Appointment appointment) async {
    if (appointment.appointmentDateTime.isBefore(DateTime.now())) {
      throw Exception('Appointment date and time must be in the future.');
    }

    final response = await _client
        .from('appointments')
        .insert(appointment.toMap())
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('Failed to create appointment.');
    }

    final id = (response as Map<String, dynamic>)['id'] as String?;
    await logActivity(
      action: 'booked_appointment',
      entityType: 'appointment',
      entityId: id,
      details: {
        'clinic_id': appointment.clinicId,
        'service_name': appointment.serviceName,
        'appointment_datetime': appointment.appointmentDateTime.toIso8601String(),
      },
    );
    return id;
  }

  Future<List<Appointment>> fetchPatientAppointments(String patientId) async {
    final response = await _client
        .from('appointments')
        .select('*, clinics(name)')
        .eq('patient_id', patientId)
        .order('appointment_datetime', ascending: true);

    if (response is! List) return [];
    return response
        .map((map) => Appointment.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  Future<List<Appointment>> fetchClinicAppointments(String clinicId) async {
    final response = await _client
        .from('appointments')
        .select('*, profiles(full_name)')
        .eq('clinic_id', clinicId)
        .order('appointment_datetime', ascending: true);

    if (response is! List) return [];
    return response
        .map((map) => Appointment.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  Future<List<Appointment>> fetchBookedSlots(String clinicId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final response = await _client
        .from('appointments')
        .select('appointment_datetime, status')
        .eq('clinic_id', clinicId)
        .gte('appointment_datetime', start.toUtc().toIso8601String())
        .lt('appointment_datetime', end.toUtc().toIso8601String())
        .neq('status', 'cancelled')
        .neq('status', 'denied');

    if (response is! List) return [];
    return response
        .map((map) => Appointment.fromMap({
              ...map as Map<String, dynamic>,
              'patient_id': '',
              'clinic_id': clinicId,
              'service_name': '',
              'contact_number': '',
            }))
        .toList();
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    await _client.from('appointments').update({'status': status}).eq('id', id);
    await logActivity(
      action: 'updated_appointment_status',
      entityType: 'appointment',
      entityId: id,
      details: {'status': status},
    );
  }

  Future<void> cancelAppointment(String id) async {
    await updateAppointmentStatus(id, 'cancelled');
    await logActivity(
      action: 'cancelled_appointment',
      entityType: 'appointment',
      entityId: id,
    );
  }
}
