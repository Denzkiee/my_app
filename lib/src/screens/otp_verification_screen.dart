import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/otp_flow.dart';
import '../services/database_service.dart';
import '../utils/app_router.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const routeName = '/otp-verify';

  final OtpVerificationArgs args;

  const OtpVerificationScreen({super.key, required this.args});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  bool get _isRegistration => widget.args.flow == OtpFlowType.registration;

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _errorText = 'Enter the 6-digit OTP code.');
      return;
    }

    if (!_isRegistration) {
      if (_passwordController.text.length < 6) {
        setState(() => _errorText = 'New password must be at least 6 characters.');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _errorText = 'Passwords do not match.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      if (_isRegistration) {
        final user = await DatabaseService.instance.verifyRegistrationOtp(
          email: widget.args.email,
          token: otp,
          fullName: widget.args.fullName!,
          role: widget.args.role!,
        );
        if (!mounted || user == null) return;
        AppRouter.navigateToHome(context, user);
      } else {
        await DatabaseService.instance.verifyPasswordResetOtp(
          email: widget.args.email,
          token: otp,
          newPassword: _passwordController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. You can now sign in.')),
        );
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    } catch (error) {
      setState(() => _errorText = error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      if (_isRegistration) {
        await DatabaseService.instance.resendRegistrationOtp(widget.args.email);
      } else {
        await DatabaseService.instance.sendPasswordResetOtp(widget.args.email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP code has been sent.')),
      );
    } catch (error) {
      setState(() => _errorText = error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistration ? 'Verify Email' : 'Reset Password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegistration
                        ? 'Enter the 6-digit OTP sent to your email'
                        : 'Enter the OTP and your new password',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.args.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      counterText: '',
                    ),
                  ),
                  if (!_isRegistration) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm New Password'),
                    ),
                  ],
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorText!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isRegistration ? 'Verify & Continue' : 'Update Password'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : _resend,
                    child: const Text('Resend OTP'),
                  ),
                  if (!_isRegistration)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pushReplacementNamed(
                                ForgotPasswordScreen.routeName,
                              ),
                      child: const Text('Use a different email'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
