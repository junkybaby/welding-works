import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:welding_works/admin_mobile_ui.dart';
import 'package:welding_works/app_routes.dart';
import 'package:welding_works/auth_session.dart';
import 'package:welding_works/app_config.dart';
import 'package:welding_works/forgot_password_page.dart';
import 'package:welding_works/otp_page.dart';
import 'package:welding_works/signup_page.dart';
import 'package:welding_works/trainer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeldingWorksApp());
}

class WeldingWorksApp extends StatelessWidget {
  const WeldingWorksApp({super.key});

  @override
  Widget build(BuildContext context) {
    const tesdaBlue = AdminMobilePalette.primary;
    const tesdaRed = Color(0xFFC21F1F);
    const tesdaGold = Color(0xFFF2C94C);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: tesdaBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: tesdaBlue,
      secondary: tesdaGold,
      tertiary: tesdaRed,
    );

    return MaterialApp(
      title: 'Welding Works',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: tesdaBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AdminMobilePalette.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FBFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: tesdaBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: tesdaBlue,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: tesdaBlue,
            side: const BorderSide(color: tesdaBlue),
          ),
        ),
      ),
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.trainer: (_) => const TrainerDashboard(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthGateState>(
      future: _loadAuthGateState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final state = snapshot.data ?? const _AuthGateState();
        if (state.loggedIn) {
          return const TrainerDashboard();
        }
        if ((state.pendingVerificationEmail ?? "").isNotEmpty) {
          return OtpPage(email: state.pendingVerificationEmail!);
        }
        return const LoginScreen();
      },
    );
  }

  Future<_AuthGateState> _loadAuthGateState() async {
    final loggedIn = await AuthSession.isLoggedIn();
    final pendingVerificationEmail = await AuthSession.getPendingVerificationEmail();
    return _AuthGateState(
      loggedIn: loggedIn,
      pendingVerificationEmail: pendingVerificationEmail,
    );
  }
}

class _AuthGateState {
  const _AuthGateState({
    this.loggedIn = false,
    this.pendingVerificationEmail,
  });

  final bool loggedIn;
  final String? pendingVerificationEmail;
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: size.height,
            width: size.width,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AdminMobilePalette.primaryDark,
                  AdminMobilePalette.primary,
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _BrandHeader(colorScheme: colorScheme),
                            const SizedBox(height: 28),
                            _LoginCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Welding Works',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Simple trainer access, assessment, and batch tools.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LoginCard extends StatefulWidget {
  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _loginUser() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password.')),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      final url = Uri.parse("${AppConfig.weldingApi}/login.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": identifier,
          "email": identifier,
          "username": identifier,
          "password": password,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }

      if (!mounted) return;
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data["status"] == "success") {
          final email = (data["email"] ?? identifier).toString();
          final username = (data["username"] ?? identifier).toString();
          await AuthSession.clearPendingVerificationEmail();
          await AuthSession.setLoggedIn(
            value: true,
            email: email,
            username: username,
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(AppRoutes.trainer);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Login failed")),
        );
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
          _isLoggingIn = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminMobileCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminMobileBadge('Trainer Access'),
          const SizedBox(height: 16),
          const Text(
            'Trainer Login',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to manage batches, assess trainees, and review records.',
            style: TextStyle(
              color: AdminMobilePalette.muted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
              controller: _identifierController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@gmail.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            obscureText: _obscurePassword,
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: _togglePasswordVisibility,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
              },
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: adminActionButtonStyle(),
              onPressed: _isLoggingIn ? null : _loginUser,
              child: Text(_isLoggingIn ? 'Signing in...' : 'Sign in'),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 6),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text("Don't have an account? "),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignUpPage(),
                      ),
                    );
                  },
                  child: const Text('Sign up'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
