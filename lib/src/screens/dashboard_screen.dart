import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import 'book_appointment_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? _user;
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    _user = await DatabaseService.instance.getCurrentUser();
    if (_user?.role == 'admin') {
      _appointments = await DatabaseService.instance.fetchAppointments();
    } else {
      _appointments = await DatabaseService.instance.fetchAppointments(userId: _user?.id);
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await DatabaseService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  Future<void> _updateAppointmentStatus(Appointment appointment, String status) async {
    await DatabaseService.instance.updateAppointmentStatus(appointment.id!, status);
    await _loadData();
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    await DatabaseService.instance.deleteAppointment(appointment.id!);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dental Office Dashboard'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Welcome, ${_user?.fullName ?? 'Team'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Manage patients, appointments, and booking securely.'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_user?.id == null) return;
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookAppointmentScreen(userId: _user!.id!)));
                      await _loadData();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(_user?.role == 'admin' ? 'Book Appointment' : 'Book Your Session'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _user?.role == 'admin' ? 'Admin Panel — All Appointments' : 'Your Booked Sessions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_appointments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          _user?.role == 'admin'
                              ? 'No appointments have been booked yet.'
                              : 'You have no booked sessions yet.',
                        ),
                      ),
                    )
                  else
                    ..._appointments.map((appointment) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${appointment.patientName} • ${appointment.serviceType}',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${appointment.dentistName} · ${appointment.dateTime.toLocal()}'.replaceFirst(' 00:00:00.000', ''),
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        if (_user?.role == 'admin' && appointment.userId != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text('Booked by user id: ${appointment.userId}', style: Theme.of(context).textTheme.bodySmall),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_user?.role == 'admin')
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'Complete') {
                                          await _updateAppointmentStatus(appointment, 'Completed');
                                        } else if (value == 'Cancel') {
                                          await _updateAppointmentStatus(appointment, 'Canceled');
                                        } else if (value == 'Delete') {
                                          await _deleteAppointment(appointment);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'Complete', child: Text('Mark Completed')),
                                        const PopupMenuItem(value: 'Cancel', child: Text('Cancel Appointment')),
                                        const PopupMenuItem(value: 'Delete', child: Text('Delete Appointment')),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  Chip(
                                    label: Text(appointment.status),
                                    backgroundColor: appointment.status == 'Completed'
                                        ? Colors.green[100]
                                        : appointment.status == 'Canceled'
                                            ? Colors.red[100]
                                            : Colors.orange[100],
                                  ),
                                  if (_user?.role == 'admin')
                                    Text('Patient: ${appointment.patientName}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
