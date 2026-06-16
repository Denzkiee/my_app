import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../widgets/account_menu_button.dart';
import '../login_screen.dart';
import 'clinic_application_screen.dart';
import 'clinic_availability_screen.dart';
import 'clinic_bookings_screen.dart';
import 'clinic_services_screen.dart';

class ClinicHomeScreen extends StatefulWidget {
  static const routeName = '/clinic';

  const ClinicHomeScreen({super.key});

  @override
  State<ClinicHomeScreen> createState() => _ClinicHomeScreenState();
}

class _ClinicHomeScreenState extends State<ClinicHomeScreen> {
  int _tabIndex = 0;

  Future<void> _logout() async {
    await DatabaseService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['My Clinic', 'Services', 'Hours', 'Bookings'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tabIndex]),
        actions: [
          AccountMenuButton(onLogout: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          ClinicApplicationScreen(),
          ClinicServicesScreen(),
          ClinicAvailabilityScreen(),
          ClinicBookingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Clinic'),
          NavigationDestination(icon: Icon(Icons.medical_services_outlined), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Hours'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'Bookings'),
        ],
      ),
    );
  }
}
