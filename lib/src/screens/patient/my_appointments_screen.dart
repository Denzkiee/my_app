import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../services/database_service.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    final user = await DatabaseService.instance.getCurrentUser();
    if (user?.id != null) {
      _appointments = await DatabaseService.instance.fetchPatientAppointments(user!.id!);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: const Text('This will cancel your booking request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirmed != true || appointment.id == null) return;

    await DatabaseService.instance.cancelAppointment(appointment.id!);
    await _loadAppointments();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade100;
      case 'denied':
      case 'cancelled':
        return Colors.red.shade100;
      case 'completed':
        return Colors.blue.shade100;
      default:
        return Colors.orange.shade100;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Awaiting clinic approval';
      case 'accepted':
        return 'Accepted by clinic';
      case 'denied':
        return 'Denied by clinic';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: _appointments.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('You have no booked appointments yet.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appointment = _appointments[index];
                final canCancel = appointment.status == 'pending' || appointment.status == 'accepted';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.clinicName ?? 'Clinic',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('Service: ${appointment.serviceName}'),
                        Text('When: ${appointment.appointmentDateTime.toLocal()}'),
                        if (appointment.notes.isNotEmpty) Text('Notes: ${appointment.notes}'),
                        const SizedBox(height: 10),
                        Chip(
                          label: Text(_statusLabel(appointment.status)),
                          backgroundColor: _statusColor(appointment.status),
                        ),
                        if (canCancel) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _cancel(appointment),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel'),
                            ),
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
