import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/screens/admin/admin_home_screen.dart';
import 'package:my_app/src/screens/clinic/clinic_home_screen.dart';
import 'package:my_app/src/screens/login_screen.dart';
import 'package:my_app/src/screens/patient/patient_home_screen.dart';
import 'package:my_app/src/screens/register_screen.dart';
import 'package:my_app/src/screens/splash_screen.dart';

const supabaseUrl = 'https://wfcguwmkllieugahqtax.supabase.co';
const supabaseAnonKey = 'sb_publishable_s54K1YQTlwqPHi-zv8KqHw_VKsIQlr3';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dental Booking System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        PatientHomeScreen.routeName: (_) => const PatientHomeScreen(),
        ClinicHomeScreen.routeName: (_) => const ClinicHomeScreen(),
        AdminHomeScreen.routeName: (_) => const AdminHomeScreen(),
      },
    );
  }
}
