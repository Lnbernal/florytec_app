import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';
import 'robot_screen.dart';

class ControlScreen extends StatelessWidget {
  final bool activo;
  const ControlScreen({super.key, this.activo = true});

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final dato      = mqtt.ultimoDato;
        final conectado = mqtt.status == MqttStatus.connected;
        final releOn    = dato?.rele ?? false;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Centro de Control',
                  style: TextStyle(
                    color: FloryColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Riego inteligente y robot de monitoreo',
                  style: TextStyle(color: FloryColors.textSecondary, fontSize: 12)),

                const SizedBox(height: 22),

                // Tarjeta control de relé
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: FloryColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: releOn
                          ? FloryColors.accent.withValues(alpha: 0.3)
                          : FloryColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: releOn
                                  ? FloryColors.accent.withValues(alpha: 0.15)
                                  : FloryColors.cardLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.water_rounded,
                              color: releOn ? FloryColors.accent : FloryColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sistema de Riego',
                                style: TextStyle(
                                  color: FloryColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                )),
                              Text(
                                releOn ? 'Activo — bomba encendida' : 'Inactivo — bomba apagada',
                                style: const TextStyle(
                                  color: FloryColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Botones ON / OFF
                      Row(
                        children: [
                          Expanded(
                            child: _BotonRele(
                              label: 'Activar',
                              icono: Icons.play_arrow_rounded,
                              activo: releOn,
                              color: FloryColors.accent,
                              onTap: conectado ? () => mqtt.setRele(true) : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BotonRele(
                              label: 'Apagar',
                              icono: Icons.stop_rounded,
                              activo: !releOn,
                              color: FloryColors.danger,
                              onTap: conectado ? () => mqtt.setRele(false) : null,
                            ),
                          ),
                        ],
                      ),

                      if (!conectado) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FloryColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: FloryColors.danger, size: 18),
                              SizedBox(width: 8),
                              Text('Sin conexión al broker MQTT',
                                style: TextStyle(color: FloryColors.danger, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info de valores actuales
                if (dato != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FloryColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FloryColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Valores actuales',
                          style: TextStyle(
                            color: FloryColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FilaValor('Temperatura',    '${dato.temperatura}°C'),
                        _FilaValor('Humedad Aire',   '${dato.humedadAire.toStringAsFixed(0)}%'),
                        _FilaValor('Humedad Suelo',  '${dato.humedadSuelo}%'),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                const Divider(color: FloryColors.border),
                const SizedBox(height: 18),
                RobotScreen(activo: activo, integrado: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BotonRele extends StatelessWidget {
  final String label;
  final IconData icono;
  final bool activo;
  final Color color;
  final VoidCallback? onTap;

  const _BotonRele({
    required this.label,
    required this.icono,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: activo ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 20,
              color: activo ? FloryColors.background : color),
            const SizedBox(width: 8),
            Text(label,
              style: TextStyle(
                color: activo ? FloryColors.background : color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaValor extends StatelessWidget {
  final String label;
  final String valor;
  const _FilaValor(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: FloryColors.textSecondary, fontSize: 13)),
          Text(valor,  style: const TextStyle(color: FloryColors.textPrimary,  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
