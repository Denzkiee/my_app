import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../models/clinic.dart';
import '../../services/database_service.dart';

class ClinicBookingsScreen extends StatefulWidget {
  const ClinicBookingsScreen({super.key});

  @override
  State<ClinicBookingsScreen> createState() => _ClinicBookingsScreenState();
}

class _ClinicBookingsScreenState extends State<ClinicBookingsScreen> {
  Clinic? _clinic;
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final user = await DatabaseService.instance.getCurrentUser();
    if (user?.id != null) {
      _clinic = await DatabaseService.instance.fetchClinicByOwner(user!.id!);
      if (_clinic?.id != null) {
        _appointments = await DatabaseService.instance.fetchClinicAppointments(_clinic!.id!);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _respond(Appointment appointment, String status) async {
    if (appointment.id == null) return;
    await DatabaseService.instance.updateAppointmentStatus(appointment.id!, status);
    await _loadData();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade100;
      case 'denied':
      case 'cancelled':
        return Colors.red.shade100;
      default:
        return Colors.orange.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clinic == null) {
      return const Center(child: Text('Submit your clinic application first.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: _appointments.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No patient bookings yet.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appointment = _appointments[index];
                final isPending = appointment.status == 'pending';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName ?? 'Patient',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('Service: ${appointment.serviceName}'),
                        Text('When: ${appointment.appointmentDateTime.toLocal()}'),
                        Text('Contact: ${appointment.contactNumber}'),
                        if (appointment.notes.isNotEmpty) Text('Notes: ${appointment.notes}'),
                        const SizedBox(height: 10),
                        Chip(
                          label: Text(appointment.status),
                          backgroundColor: _statusColor(appointment.status),
                        ),
                        if (isPending) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _respond(appointment, 'denied'),
                                child: const Text('Deny'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _respond(appointment, 'accepted'),
                                child: const Text('Accept'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
