import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:welding_works/admin_mobile_ui.dart';
import 'package:welding_works/app_config.dart';
import 'package:welding_works/app_routes.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isSending = false;
  bool isResetting = false;
  bool otpSent = false;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

    bool hasUpper = false;
    bool hasLower = false;
    bool hasNumber = false;
    bool hasSpecial = false;
    bool hasMinLength = false;
    bool showConfirmPasswordError = false;
    bool showPasswordRequirements = false;

  bool _validEmail() {
    final value = emailController.text.trim();
    return value.isNotEmpty && value.endsWith("@gmail.com");
  }

    void _updatePasswordRules(String value) {
      setState(() {
        showPasswordRequirements = value.isNotEmpty;
        hasUpper = RegExp(r'[A-Z]').hasMatch(value);
        hasLower = RegExp(r'[a-z]').hasMatch(value);
        hasNumber = RegExp(r'[0-9]').hasMatch(value);
        hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);
        hasMinLength = value.length >= 8;
        showConfirmPasswordError =
            confirmPasswordController.text.isNotEmpty &&
                confirmPasswordController.text != value;
      });
    }

  bool _passwordsValid() {
    final pass = passwordController.text;
    return hasUpper &&
        hasLower &&
        hasNumber &&
        hasSpecial &&
        hasMinLength &&
        pass.isNotEmpty &&
        pass == confirmPasswordController.text;
  }

  Future<void> _sendOtp() async {
    if (!_validEmail()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid Gmail address.")),
      );
      return;
    }

    setState(() => isSending = true);
    try {
      final url =
          Uri.parse("${AppConfig.weldingApi}/request_password_reset.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailController.text.trim().toLowerCase()}),
      );

      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }

      if (!mounted) return;
        final data = jsonDecode(response.body);
        final message = (data is Map ? data["message"] : null)?.toString();
      if (data is Map && data["status"] == "success") {
        setState(() => otpSent = true);
      }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? "OTP sent",
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_validEmail()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid Gmail address.")),
      );
      return;
    }

    if (otpController.text.trim().isEmpty || !_passwordsValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete OTP and password fields.")),
      );
      return;
    }

    setState(() => isResetting = true);
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/reset_password.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim().toLowerCase(),
          "otp": otpController.text.trim(),
          "password": passwordController.text,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }

      if (!mounted) return;
        final data = jsonDecode(response.body);
        final message = (data is Map ? data["message"] : null)?.toString();
      if (data is Map && data["status"] == "success") {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? "Reset failed",
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isResetting = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminMobileScaffold(
      title: 'Forgot Password',
      subtitle: 'Use the same clear recovery flow as the admin.',
      body: AdminMobileBody(
        children: [
          AdminMobileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminMobileBadge('Account Recovery'),
                const SizedBox(height: 16),
                const Text(
                  "Reset your password",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Request an OTP first, then set a new password once your code arrives.",
                  style: TextStyle(
                    color: AdminMobilePalette.muted,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email (Gmail only)",
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: adminActionButtonStyle(),
                    onPressed: isSending ? null : _sendOtp,
                    child: Text(isSending ? "Sending..." : "Send OTP"),
                  ),
                ),
                const SizedBox(height: 22),
                if (otpSent) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "OTP",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isSending ? null : _sendOtp,
                      child: Text(isSending ? "Sending..." : "Resend OTP"),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    onChanged: _updatePasswordRules,
                  ),
                  const SizedBox(height: 8),
                  if (showPasswordRequirements &&
                      !(hasUpper &&
                          hasLower &&
                          hasNumber &&
                          hasSpecial &&
                          hasMinLength))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRequirement("At least 1 uppercase letter", hasUpper),
                        _buildRequirement("At least 1 lowercase letter", hasLower),
                        _buildRequirement("At least 1 number", hasNumber),
                        _buildRequirement("At least 1 special character", hasSpecial),
                        _buildRequirement("At least 8 characters", hasMinLength),
                      ],
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        showConfirmPasswordError =
                            value.isNotEmpty && value != passwordController.text;
                      });
                    },
                  ),
                  if (showConfirmPasswordError)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "Passwords do not match",
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: adminActionButtonStyle(),
                      onPressed: isResetting ? null : _resetPassword,
                      child: Text(
                        isResetting ? "Resetting..." : "Reset Password",
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool condition) {
    if (condition) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }
}
