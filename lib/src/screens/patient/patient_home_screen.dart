import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../services/database_service.dart';
import '../login_screen.dart';
import 'book_clinic_screen.dart';
import 'my_appointments_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  static const routeName = '/patient';

  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _tabIndex = 0;
  List<Clinic> _clinics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    setState(() => _loading = true);
    _clinics = await DatabaseService.instance.fetchApprovedClinics();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    await DatabaseService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Find Clinics' : 'My Appointments'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _tabIndex == 0 ? _buildClinicsTab() : const MyAppointmentsScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_hospital_outlined), label: 'Clinics'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'My Bookings'),
        ],
      ),
    );
  }

  Widget _buildHoursSection(Clinic clinic) {
    if (clinic.availability.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Open hours not listed yet',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    final sorted = [...clinic.availability]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                'Open hours',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...sorted.map(
            (slot) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      slot.dayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${slot.startTime} – ${slot.endTime}',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadClinics,
      child: _clinics.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No approved clinics are available yet.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _clinics.length,
              itemBuilder: (context, index) {
                final clinic = _clinics[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BookClinicScreen(clinic: clinic)),
                      );
                      if (_tabIndex == 1 && mounted) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade50,
                            child: Icon(Icons.local_hospital, color: Colors.teal.shade700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clinic.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                if (clinic.address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(clinic.address, style: TextStyle(color: Colors.grey.shade700)),
                                ],
                                if (clinic.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    clinic.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                                _buildHoursSection(clinic),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
