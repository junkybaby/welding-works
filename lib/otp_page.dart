import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:welding_works/admin_mobile_ui.dart';
import 'package:welding_works/auth_session.dart';
import 'app_config.dart';
import 'package:welding_works/app_routes.dart';

class OtpPage extends StatefulWidget {
  final String email;

  const OtpPage({super.key, required this.email});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController otpController = TextEditingController();

  Future<void> verifyOtp() async {
    try {
      final otp = otpController.text.trim();
      if (otp.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter the OTP.")),
        );
        return;
      }

      final url = Uri.parse("${AppConfig.weldingApi}/verify_otp.php");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email.trim().toLowerCase(),
          "otp": otp,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error");
      }

      if (!mounted) return;
      try {
        final data = jsonDecode(response.body);
        final status = (data is Map ? data["status"] : null)?.toString();
        final message = (data is Map ? data["message"] : null)?.toString();

        if (status == "success") {
          final email = (data["email"] ?? widget.email).toString();
          final username = (data["username"] ?? widget.email.split("@").first)
              .toString();
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Account Verified"),
              content: const Text(
                "Your account has been verified successfully.",
              ),
              actions: [
                FilledButton(
                  style: adminActionButtonStyle(),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Continue"),
                ),
              ],
            ),
          );
          if (!mounted) return;
          await AuthSession.clearPendingVerificationEmail();
          await AuthSession.setLoggedIn(
            value: true,
            email: email,
            username: username,
          );
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.trainer,
            (route) => false,
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? "OTP verification failed.")),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Server returned non-JSON. Status ${response.statusCode}",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification error: $e")),
      );
    }
  }

  Future<void> resendOtp() async {
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/resend_otp.php");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error");
      }

      if (!mounted) return;
      try {
        final data = jsonDecode(response.body);
        final message = (data is Map ? data["message"] : null)?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? "OTP resent.")),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "OTP resend returned non-JSON. Status ${response.statusCode}",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Resend error: $e")),
      );
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminMobileScaffold(
      title: 'Verify OTP',
      subtitle: 'Finish account verification before signing in.',
      body: AdminMobileBody(
        children: [
          AdminMobileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminMobileBadge('Verification'),
                const SizedBox(height: 16),
                const Text(
                  "Enter OTP",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AdminMobilePalette.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We sent a code to ${widget.email}.",
                  style: const TextStyle(
                    color: AdminMobilePalette.muted,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "OTP",
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: adminActionButtonStyle(),
                    onPressed: verifyOtp,
                    child: const Text("Verify"),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: resendOtp,
                    child: const Text("Resend OTP"),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This verification step will stay here until your account is confirmed.",
                  style: TextStyle(
                    color: AdminMobilePalette.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          AdminMobileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Next Step",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminMobilePalette.text,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Once verified, your trainer account will open automatically.",
                  style: TextStyle(
                    color: AdminMobilePalette.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
