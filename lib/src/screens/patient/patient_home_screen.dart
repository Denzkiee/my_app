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
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_hospital)),
                    title: Text(clinic.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (clinic.address.isNotEmpty) Text(clinic.address),
                        if (clinic.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(clinic.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BookClinicScreen(clinic: clinic)),
                      );
                      if (_tabIndex == 1 && mounted) setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
