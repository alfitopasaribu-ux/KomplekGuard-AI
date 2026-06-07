import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NexusGuard {
  static const Color bg = Color(0xFF020617);
  static const Color bg2 = Color(0xFF050B1A);
  static const Color panel = Color(0xFF0F172A);
  static const Color border = Color(0xFF1E293B);

  static const Color cyan = Color(0xFF22D3EE);
  static const Color cyan2 = Color(0xFF00F5FF);
  static const Color red = Color(0xFFEF4444);
  static const Color green = Color(0xFF22C55E);
  static const Color purple = Color(0xFFA855F7);
  static const Color amber = Color(0xFFF59E0B);

  static const Color text = Color(0xFFF8FAFC);
  static const Color muted = Color(0xFF94A3B8);
  static const Color muted2 = Color(0xFF64748B);

  static TextStyle orbitron({
    double size = 16,
    Color color = text,
    FontWeight weight = FontWeight.w700,
    double spacing = 0.8,
  }) {
    return GoogleFonts.orbitron(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
    );
  }

  static TextStyle rajdhani({
    double size = 16,
    Color color = text,
    FontWeight weight = FontWeight.w600,
    double spacing = 0.2,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
    );
  }

  static TextStyle mono({
    double size = 13,
    Color color = muted,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.shareTechMono(
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }

  static BoxDecoration card({
    Color? glow,
    double radius = 22,
    bool active = false,
  }) {
    return BoxDecoration(
      color: panel.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: active
            ? (glow ?? cyan).withValues(alpha: 0.55)
            : border.withValues(alpha: 0.9),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        if (glow != null)
          BoxShadow(
            color: glow.withValues(alpha: active ? 0.25 : 0.12),
            blurRadius: active ? 34 : 20,
            spreadRadius: active ? 1 : 0,
          ),
      ],
    );
  }
}

class NexusBackground extends StatelessWidget {
  final Widget child;

  const NexusBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NexusGuard.bg,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          const Positioned(
            top: -90,
            left: -80,
            child: _GlowOrb(
              color: NexusGuard.cyan,
              size: 250,
              opacity: 0.10,
            ),
          ),
          const Positioned(
            bottom: -120,
            right: -90,
            child: _GlowOrb(
              color: NexusGuard.purple,
              size: 310,
              opacity: 0.12,
            ),
          ),
          const Positioned(
            top: 180,
            right: 100,
            child: _GlowOrb(
              color: NexusGuard.red,
              size: 170,
              opacity: 0.06,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: size / 2,
            spreadRadius: size / 5,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = NexusGuard.cyan.withValues(alpha: 0.045)
      ..strokeWidth = 1;

    const gap = 26.0;

    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = NexusGuard.cyan.withValues(alpha: 0.025)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 82) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    this.glowColor = NexusGuard.cyan,
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
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: NexusGuard.card(
        glow: widget.glowColor,
        active: widget.active || _hover,
      ),
      transform: Matrix4.identity()
        ..translateByDouble(0.0, _hover ? -3.0 : 0.0, 0.0, 1.0),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _Corner(color: widget.glowColor),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Transform.rotate(
              angle: pi,
              child: _Corner(color: widget.glowColor),
            ),
          ),
          widget.child,
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.onTap == null
          ? card
          : InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              child: card,
            ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;

  const _Corner({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _CornerPainter(color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width * 0.65, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height * 0.65), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NexusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const NexusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: NexusGuard.mono(
              color: color,
              size: 12,
              weight: FontWeight.w700,
            ),
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
    this.color = NexusGuard.cyan,
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
              Text(title, style: NexusGuard.orbitron(size: 16, color: color)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: NexusGuard.rajdhani(
                    size: 13,
                    color: NexusGuard.muted,
                  ),
                ),
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
      height: 64,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.90),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.7)),
          ),
        ),
        icon: Icon(icon, size: 24),
        label: Text(
          text,
          style: NexusGuard.orbitron(
            size: 15,
            weight: FontWeight.w800,
            spacing: 1.1,
          ),
        ),
      ),
    );
  }
}
