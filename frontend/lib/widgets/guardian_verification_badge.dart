import 'package:flutter/material.dart';

/// Incident verification is independent from response status and AI risk.
class GuardianVerificationBadge extends StatelessWidget {
  const GuardianVerificationBadge(this.status, {super.key, this.compact = false});

  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'TERVERIFIKASI' => 'Terverifikasi petugas',
      'PERLU_PEMERIKSAAN' => 'Perlu pemeriksaan',
      'DITOLAK' => 'Verifikasi ditolak',
      _ => 'Belum terverifikasi',
    };
    final color = switch (status) {
      'TERVERIFIKASI' => const Color(0xFF087D65),
      'DITOLAK' => const Color(0xFFB2473F),
      _ => const Color(0xFF9A721D),
    };
    return Semantics(
      label: 'Status verifikasi: $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 11,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        )),
      ),
    );
  }
}
