import 'package:flutter/material.dart';

import '../models/user.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/clinic/clinic_home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/patient/patient_home_screen.dart';

class AppRouter {
  static String homeRouteFor(User user) {
    if (user.isAdmin) return AdminHomeScreen.routeName;
    if (user.isClinic) return ClinicHomeScreen.routeName;
    return PatientHomeScreen.routeName;
  }

  static void navigateToHome(BuildContext context, User user) {
    Navigator.of(context).pushReplacementNamed(homeRouteFor(user));
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }
}
