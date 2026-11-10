import 'package:flutter/material.dart';

/// Shared visual language. Legacy names remain available to existing screens.
class NexusGuard {
  static const emerald = Color(0xFF18776A);
  static const slate = Color(0xFF172D36);
  static const ivory = Color(0xFFF5F6F2);
  static const red = Color(0xFFC54648);
  static const amber = Color(0xFFD49A43);
  static const success = Color(0xFF27A77D);

  static const bg = ivory;
  static const bg2 = Color(0xFFEDF3EE);
  static const panel = Colors.white;
  static const border = Color(0xFFDFE7E1);
  static const text = slate;
  static const muted = Color(0xFF617178);
  static const muted2 = Color(0xFF77858A);

  // Compatibility with screens outside this UI phase.
  static const cyan = emerald;
  static const cyan2 = emerald;
  static const green = success;
  static const purple = Color(0xFF397E74);

  static ThemeData get theme {
    final colors = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.light,
    ).copyWith(
      primary: emerald,
      onPrimary: Colors.white,
      secondary: slate,
      onSecondary: Colors.white,
      tertiary: success,
      error: red,
      onError: Colors.white,
      surface: panel,
      onSurface: slate,
      onSurfaceVariant: muted,
      outline: border,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: ivory,
      visualDensity: VisualDensity.standard,
    );
    final typography = base.textTheme.apply(
      bodyColor: slate,
      displayColor: slate,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return base.copyWith(
      textTheme: typography.copyWith(
        headlineLarge: typography.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          height: 1.2,
        ),
        headlineMedium: typography.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          height: 1.25,
        ),
        titleLarge: typography.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: typography.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyLarge: typography.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: typography.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        bodySmall: typography.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.4,
          color: muted,
        ),
        labelLarge: typography.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: panel,
        foregroundColor: slate,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: slate,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded.copyWith(side: const BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: panel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        hintStyle: const TextStyle(color: muted2, fontSize: 14),
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFDCE8E2),
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: typography.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: rounded,
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 54),
          textStyle: typography.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emerald,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emerald,
          textStyle: typography.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: emerald),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slate,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Color(0xFFE4F1EB),
        elevation: 0,
      ),
    );
  }

  // These public helpers keep existing feature screens source-compatible.
  static TextStyle orbitron({
    double size = 16,
    Color color = text,
    FontWeight weight = FontWeight.w700,
    double spacing = 0,
  }) =>
      TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing.clamp(-0.4, 0.6).toDouble(),
        height: 1.3,
      );

  static TextStyle rajdhani({
    double size = 16,
    Color color = text,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
  }) =>
      TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: spacing,
        height: 1.5,
      );

  static TextStyle mono({
    double size = 13,
    Color color = muted,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.4);

  static BoxDecoration card({
    Color? glow,
    double radius = 22,
    bool active = false,
  }) =>
      BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active ? (glow ?? emerald).withValues(alpha: 0.35) : border,
        ),
        boxShadow: [
          BoxShadow(
            color: slate.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

class NexusBackground extends StatelessWidget {
  final Widget child;

  const NexusBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: NexusGuard.bg, child: child);
}

class NexusHudCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsets padding;
  final bool active;
  final VoidCallback? onTap;

  const NexusHudCard({
    super.key,
    required this.child,
    this.glowColor = NexusGuard.emerald,
    this.padding = const EdgeInsets.all(18),
    this.active = false,
    this.onTap,
  });

  @override
  State<NexusHudCard> createState() => _NexusHudCardState();
}

class _NexusHudCardState extends State<NexusHudCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: NexusGuard.card(
          glow: widget.glowColor,
          active: widget.active || _hover,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class NexusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const NexusBadge(
      {super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6)
          ],
          Flexible(
            child: Text(text,
                style: NexusGuard.mono(
                    color: color, size: 12, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class NexusSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const NexusSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.color = NexusGuard.emerald,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: NexusGuard.orbitron(size: 18, color: NexusGuard.text)),
              if (subtitle != null)
                Text(subtitle!,
                    style:
                        NexusGuard.rajdhani(size: 13, color: NexusGuard.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class NexusPrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const NexusPrimaryButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color = NexusGuard.red,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 58),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon, size: 22),
        label: Text(text,
            textAlign: TextAlign.center,
            style: NexusGuard.orbitron(size: 15, color: Colors.white)),
      ),
    );
  }
}
