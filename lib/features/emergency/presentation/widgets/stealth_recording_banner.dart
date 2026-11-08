import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/emergency_audio_evidence.dart';
import '../controllers/emergency_coordinator.dart';

/// Banner visual discreto que muestra el estado de grabación ambiental sigilosa
/// y provee acceso directo para despachar la alerta y ubicación por WhatsApp.
class StealthRecordingBanner extends StatelessWidget {
  final EmergencyCoordinator coordinator;
  final VoidCallback? onDismiss;

  const StealthRecordingBanner({
    super.key,
    required this.coordinator,
    this.onDismiss,
  });

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs / 05:00';
  }

  void _shareViaWhatsApp(BuildContext context, EmergencyAudioEvidence evidence) {
    final message = evidence.generateWhatsAppEmergencyMessage();
    Clipboard.setData(ClipboardData(text: message));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Mensaje de emergencia y geolocalización copiado al portapapeles.'),
        backgroundColor: AppColors.successGreen,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EmergencyAudioEvidence?>(
      stream: coordinator.currentEvidenceStream,
      initialData: coordinator.currentEvidence,
      builder: (context, snapshot) {
        final evidence = snapshot.data;
        if (evidence == null) return const SizedBox.shrink();

        return StreamBuilder<int>(
          stream: coordinator.recordingDurationStream,
          initialData: evidence.durationSeconds,
          builder: (context, durationSnapshot) {
            final seconds = durationSnapshot.data ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: AppColors.panicRed.withOpacity(0.6), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.panicRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.panicRed.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'MODO SIGILOSO: Grabando Audio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Evidencia: ${_formatDuration(seconds)}',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Compartir SOS por WhatsApp',
                    icon: const Icon(Icons.share_rounded, color: Colors.greenAccent, size: 22),
                    onPressed: () => _shareViaWhatsApp(context, evidence),
                  ),
                  IconButton(
                    tooltip: 'Detener Grabación',
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.white70, size: 22),
                    onPressed: () {
                      coordinator.stopRecording();
                      onDismiss?.call();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
