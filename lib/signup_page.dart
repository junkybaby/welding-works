import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:welding_works/admin_mobile_ui.dart';
import 'package:welding_works/auth_session.dart';
import 'app_config.dart';
import 'otp_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  bool agree = false;
  bool isSubmitting = false;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSpecial = false;
  bool hasMinLength = false;

  bool showPasswordRequirements = false;

  bool showFirstNameError = false;
  bool showMiddleNameError = false;
  bool showLastNameError = false;
  bool showEmailError = false;
  bool showConfirmPasswordError = false;
  static const String traineeQualification = "SMAW NC 1";

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final RegExp nameRegex = RegExp(r"^[a-zA-Z .-]+$");

  bool _hasMinTwoLetters(String value) {
    final lettersOnly = value.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    return lettersOnly.length >= 2;
  }

  bool isFormValid() {
    return firstNameController.text.isNotEmpty &&
        nameRegex.hasMatch(firstNameController.text) &&
        _hasMinTwoLetters(firstNameController.text) &&
        (middleNameController.text.isEmpty ||
            (nameRegex.hasMatch(middleNameController.text) &&
                _hasMinTwoLetters(middleNameController.text))) &&
        lastNameController.text.isNotEmpty &&
        nameRegex.hasMatch(lastNameController.text) &&
        _hasMinTwoLetters(lastNameController.text) &&
        emailController.text.isNotEmpty &&
        emailController.text.endsWith("@gmail.com") &&
        hasUpper &&
        hasLower &&
        hasNumber &&
        hasSpecial &&
        hasMinLength &&
        confirmPasswordController.text == passwordController.text &&
        agree &&
        !isSubmitting;
  }

  Future<void> registerUser() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      final url = Uri.parse("${AppConfig.weldingApi}/register.php");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "first_name": firstNameController.text.trim(),
          "middle_name": middleNameController.text.trim(),
          "last_name": lastNameController.text.trim(),
          "email": emailController.text.trim().toLowerCase(),
          "password": passwordController.text,
          "role": "trainer",
          "status": "active",
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }

      if (!mounted) return;
        try {
          final data = jsonDecode(response.body);
          final message = (data is Map ? data["message"] : null)?.toString();
        if (data["status"] == "success") {
          await AuthSession.setPendingVerificationEmail(
            emailController.text.trim().toLowerCase(),
          );
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpPage(
                email: emailController.text.trim().toLowerCase(),
              ),
            ),
          );
        } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message ??
                      "Registration failed. Response: ${response.body}",
                ),
              ),
            );
          }
        } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Server returned non-JSON. Check API URL. "
              "Status ${response.statusCode}",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _tryResendOtp() async {
    try {
      final url = Uri.parse("${AppConfig.weldingApi}/resend_otp.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailController.text.trim().toLowerCase()}),
      );

      if (!mounted) return;
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "OTP resend failed (HTTP ${response.statusCode}). "
              "Check API host.",
            ),
          ),
        );
        return;
      }

        try {
          final data = jsonDecode(response.body);
          final message = (data is Map ? data["message"] : null)?.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message ??
                    "OTP resend attempted. Response: ${response.body}",
              ),
            ),
          );
        } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "OTP resend returned non-JSON. Check API URL. "
              "Status ${response.statusCode}",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP resend error: $e")),
      );
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminMobileScaffold(
      title: 'Create Account',
      subtitle: 'Use the same clean flow as the admin while keeping trainer signup simple.',
      body: Form(
        key: _formKey,
        child: AdminMobileBody(
          children: [
            AdminMobileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminMobileBadge('Trainer Signup'),
                  const SizedBox(height: 16),
                  const Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AdminMobilePalette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Create your trainer account to manage batches and assessments.",
                    style: TextStyle(
                      color: AdminMobilePalette.muted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: "First Name",
                ),
                onChanged: (value) {
                  setState(() {
                    showFirstNameError = value.isNotEmpty &&
                        (!nameRegex.hasMatch(value) || !_hasMinTwoLetters(value));
                  });
                },
              ),
              if (showFirstNameError)
                buildFieldError(
                  "Minimum 2 letters. Only letters, space, - and . allowed",
                ),
                  const SizedBox(height: 20),
                  TextFormField(
                controller: middleNameController,
                decoration: const InputDecoration(
                  labelText: "Middle Name (Optional)",
                ),
                onChanged: (value) {
                  setState(() {
                    showMiddleNameError = value.isNotEmpty &&
                        (!nameRegex.hasMatch(value) || !_hasMinTwoLetters(value));
                  });
                },
              ),
              if (showMiddleNameError)
                buildFieldError(
                  "Minimum 2 letters if provided. Only letters, space, - and . allowed",
                ),
                  const SizedBox(height: 20),
                  TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: "Last Name",
                ),
                onChanged: (value) {
                  setState(() {
                    showLastNameError = value.isNotEmpty &&
                        (!nameRegex.hasMatch(value) || !_hasMinTwoLetters(value));
                  });
                },
              ),
              if (showLastNameError)
                buildFieldError(
                  "Minimum 2 letters. Only letters, space, - and . allowed",
                ),
                  const SizedBox(height: 20),
                  TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email (Gmail only)",
                ),
                onChanged: (value) {
                  setState(() {
                    showEmailError =
                        value.isNotEmpty && !value.endsWith("@gmail.com");
                  });
                },
              ),
              if (showEmailError) buildFieldError("Only Gmail accounts allowed"),
                  const SizedBox(height: 20),
                  TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
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
                onChanged: (value) {
                  setState(() {
                    showPasswordRequirements = value.isNotEmpty;
                    hasUpper = RegExp(r'[A-Z]').hasMatch(value);
                    hasLower = RegExp(r'[a-z]').hasMatch(value);
                    hasNumber = RegExp(r'[0-9]').hasMatch(value);
                    hasSpecial =
                        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);
                    hasMinLength = value.length >= 8;
                    showConfirmPasswordError =
                        confirmPasswordController.text.isNotEmpty &&
                            confirmPasswordController.text != value;
                  });
                },
                validator: (_) => null,
              ),
                  const SizedBox(height: 10),
                  if (showPasswordRequirements &&
                  !(hasUpper && hasLower && hasNumber && hasSpecial && hasMinLength))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildRequirement("At least 1 uppercase letter", hasUpper),
                        buildRequirement("At least 1 lowercase letter", hasLower),
                        buildRequirement("At least 1 number", hasNumber),
                        buildRequirement("At least 1 special character", hasSpecial),
                        buildRequirement("At least 8 characters", hasMinLength),
                      ],
                    ),
                  const SizedBox(height: 20),
                  TextFormField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Re-enter Password",
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
                buildFieldError("Passwords do not match"),
                  const SizedBox(height: 15),
                  Row(
                children: [
                  Checkbox(
                    activeColor: AdminMobilePalette.primary,
                    value: agree,
                    onChanged: (value) {
                      setState(() {
                        agree = value ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      "I agree to the processing of Personal data",
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                ],
              ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: adminActionButtonStyle(),
                      onPressed: isFormValid() ? registerUser : null,
                      child: Text(
                        isSubmitting ? "Signing up..." : "Sign up",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRequirement(String text, bool condition) {
    if (condition) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 13,
        ),
      ),
    );
  }
}

Widget buildFieldError(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.red,
        fontSize: 13,
      ),
    ),
  );
}
