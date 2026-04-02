import 'package:flutter/material.dart';

class AdminMobilePalette {
  static const Color primary = Color(0xFF1F4EA1);
  static const Color primaryDark = Color(0xFF163A7A);
  static const Color primarySoft = Color(0xFFE8F0FF);
  static const Color background = Color(0xFFF2F6FC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFD7E1F0);
  static const Color text = Color(0xFF16304F);
  static const Color muted = Color(0xFF607391);
}

class AdminMobileScaffold extends StatelessWidget {
  const AdminMobileScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminMobilePalette.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE9F1FF),
              Color(0xFFF7FAFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actions != null && actions!.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: actions!,
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminMobileCard extends StatelessWidget {
  const AdminMobileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminMobilePalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminMobilePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B1F3A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AdminMobileBadge extends StatelessWidget {
  const AdminMobileBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AdminMobilePalette.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AdminMobilePalette.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class AdminMobileBody extends StatelessWidget {
  const AdminMobileBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(0, 18, 0, 24),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: children,
    );
  }
}

class AdminMobileSegment extends StatelessWidget {
  const AdminMobileSegment({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: selected
            ? AdminMobilePalette.primary
            : AdminMobilePalette.primarySoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AdminMobilePalette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle adminActionButtonStyle({
  Color background = AdminMobilePalette.primary,
  Color foreground = Colors.white,
}) {
  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
  );
}
