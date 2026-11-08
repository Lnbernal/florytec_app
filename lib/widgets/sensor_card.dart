import 'package:flutter/material.dart';
import '../theme.dart';

class SensorCard extends StatelessWidget {
  final IconData icono;
  final String   titulo;
  final String   valor;
  final String   estado;
  final Color    colorIcono;
  final bool     esAlerta;

  const SensorCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.estado,
    this.colorIcono  = FloryColors.accent,
    this.esAlerta    = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorEstado = esAlerta ? FloryColors.warning : FloryColors.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FloryColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esAlerta
              ? FloryColors.warning.withValues(alpha: 0.3)
              : FloryColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: colorIcono, size: 28),
          const SizedBox(height: 12),
          Text(titulo,
            style: const TextStyle(
              color: FloryColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(valor,
            style: const TextStyle(
              color: FloryColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(estado,
              style: TextStyle(
                color: colorEstado,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
