import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../widgets/account_menu_button.dart';
import '../login_screen.dart';
import 'active_clinics_screen.dart';
import 'activity_logs_screen.dart';
import 'clinic_applications_screen.dart';
import 'clinic_appeals_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  static const routeName = '/admin';

  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tabIndex = 0;

  static const _titles = [
    'Clinic Applications',
    'Active Clinics',
    'Appeals',
    'Activity Logs',
  ];

  Future<void> _logout() async {
    await DatabaseService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        actions: [
          AccountMenuButton(onLogout: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          ClinicApplicationsScreen(),
          ActiveClinicsScreen(),
          ClinicAppealsScreen(),
          ActivityLogsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.approval_outlined), label: 'Applications'),
          NavigationDestination(icon: Icon(Icons.local_hospital_outlined), label: 'Active'),
          NavigationDestination(icon: Icon(Icons.gavel_outlined), label: 'Appeals'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Logs'),
        ],
      ),
    );
  }
}
