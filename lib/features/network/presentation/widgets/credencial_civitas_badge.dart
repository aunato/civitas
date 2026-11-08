import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Widget de credencial oficial de seguridad vecinal CIVITAS.
/// Cumple con la especificación de tesis para validación y disuasión de suplantación.
class CredencialCivitasBadge extends StatelessWidget {
  final String nombre;
  final String? rut;
  final String rol;
  final int reputacion;
  final String folio;
  final bool isCompact;
  final VoidCallback? onShare;

  const CredencialCivitasBadge({
    super.key,
    required this.nombre,
    this.rut,
    required this.rol,
    this.reputacion = 100,
    required this.folio,
    this.isCompact = false,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryLight.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.primaryLight, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'CIVITAS: $folio',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(90),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF60A5FA).withAlpha(120), width: 1.5),
      ),
      child: Stack(
        children: [
          // Marca de agua de fondo
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.08,
              child: const Icon(
                Icons.shield_rounded,
                size: 190,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera institucional
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 1),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.amberAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'REPÚBLICA DE CHILE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'CREDENCIAL CIVITAS DIGITAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'VIGENTE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),

                // Información del usuario
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TITULAR AUTORIZADO',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (rut != null && rut!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'RUT: $rut',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Código QR de Validación
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.qr_code_2_rounded, size: 48, color: AppColors.primaryDark),
                          Text(
                            'VALIDAR',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Fila de Rol y Reputación
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaChip(
                      label: 'ROL ASIGNADO',
                      value: rol,
                      icon: Icons.badge_outlined,
                    ),
                    _buildMetaChip(
                      label: 'REPUTACIÓN',
                      value: '$reputacion PTS',
                      icon: Icons.star_rate_rounded,
                      valueColor: Colors.amberAccent,
                    ),
                    _buildMetaChip(
                      label: 'FOLIO DE SEGURIDAD',
                      value: folio,
                      icon: Icons.security_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),

                // Pie de credencial
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Red de Protección Comunitaria • Tesis CIVITAS 2026',
                        style: TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                    ),
                    if (onShare != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onShare,
                        icon: const Icon(Icons.share, size: 14),
                        label: const Text('Compartir', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required String value,
    required IconData icon,
    Color valueColor = Colors.white,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: valueColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
