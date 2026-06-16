enum OtpFlowType { registration, passwordReset }

class OtpVerificationArgs {
  final String email;
  final OtpFlowType flow;
  final String? fullName;
  final String? role;

  const OtpVerificationArgs({
    required this.email,
    required this.flow,
    this.fullName,
    this.role,
  });
}
