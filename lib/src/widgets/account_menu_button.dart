import 'package:flutter/material.dart';

import '../screens/change_password_screen.dart';

class AccountMenuButton extends StatelessWidget {
  final VoidCallback onLogout;

  const AccountMenuButton({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'password') {
          Navigator.of(context).pushNamed(ChangePasswordScreen.routeName);
        } else if (value == 'logout') {
          onLogout();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'password', child: Text('Change Password')),
        PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}
