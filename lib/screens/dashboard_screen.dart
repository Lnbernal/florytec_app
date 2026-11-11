
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/mqtt_service.dart';
import '../theme.dart';
import '../widgets/sensor_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Referencia provisional del MQ-135.
  // Reemplazar después de estabilizar y calibrar el sensor.
  static const int _referenciaMQ135 = 1777;

  String _estadoTemp(double t) {
    if (t < 15) return 'Muy frío';
    if (t < 18) return 'Frío';
    if (t <= 28) return 'Óptimo';
    return 'Caliente';
  }

  String _estadoHumAire(double h) {
    if (h < 40) return 'Bajo';
    if (h <= 70) return 'Óptimo';
    return 'Alto';
  }

  String _estadoSuelo(int s) {
    if (s < 30) return 'Seco';
    if (s <= 70) return 'Óptimo';
    return 'Húmedo';
  }

  // =====================================
  // CALIDAD DEL AIRE MQ-135
  // =====================================

  double _variacionAire(int adc) {
    return (adc - _referenciaMQ135).abs() *
        100.0 / _referenciaMQ135;
  }

  String _valorAire(int? adc) {
    if (adc == null) return '--';

    if (adc <= 0 || adc >= 4095) {
      return 'Revisar';
    }

    final variacion = _variacionAire(adc);

    if (variacion <= 10) return 'Estable';
    if (variacion <= 25) return 'Vigilar';

    return 'Revisar';
  }

  String _estadoAire(int? adc) {
    if (adc == null) return 'Sin lectura';

    if (adc <= 0 || adc >= 4095) {
      return 'Revisar sensor';
    }

    final variacion = _variacionAire(adc);

    return 'Cambio: ${variacion.toStringAsFixed(0)}%';
  }

  bool _alertaAire(int? adc) {
    if (adc == null) return false;

    return adc <= 0 ||
        adc >= 4095 ||
        _variacionAire(adc) > 25;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final dato = mqtt.ultimoDato;
        final robot = mqtt.robotDato;

        final conectado =
            mqtt.status == MqttStatus.connected;

        // Utilizar los datos del robot cuando no
        // existan lecturas del invernadero.
        final temperatura =
            dato?.temperatura ?? robot?.temperatura;

        final humedadAire =
            dato?.humedadAire ?? robot?.humedadAire;

        final humedadSuelo =
            dato?.humedadSuelo ?? robot?.humedadSuelo;

        final humedadSueloADC = robot?.humedadSueloRaw;

        // El relé solo se muestra si reporta su estado.
        final rele = dato?.rele;

        // Lectura MQ-135 recibida del robot.
        final calidadAire = robot?.mq135Raw;

        final ultimaFecha =
            dato?.timestamp ?? mqtt.ultimaLecturaRobot;

        final hayDatos = dato != null || robot != null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar original
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi Invernadero',
                          style: TextStyle(
                            color: FloryColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Monitoreo en tiempo real',
                          style: TextStyle(
                            color: FloryColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Indicador de conexión original
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: conectado
                            ? FloryColors.accent
                                .withValues(alpha: 0.12)
                            : FloryColors.danger
                                .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: conectado
                                  ? FloryColors.accent
                                  : FloryColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mqtt.status == MqttStatus.connecting
                                ? 'Conectando...'
                                : conectado
                                    ? 'En línea'
                                    : 'Sin conexión',
                            style: TextStyle(
                              color: conectado
                                  ? FloryColors.accent
                                  : FloryColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sin datos aún
                if (!hayDatos) ...[
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: FloryColors.accent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            conectado
                                ? 'Esperando datos del ESP32...'
                                : 'Conectando al broker MQTT...',
                            style: const TextStyle(
                              color:
                                  FloryColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Grid de tarjetas original
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                      children: [
                        // Temperatura
                        SensorCard(
                          icono: Icons.thermostat_rounded,
                          titulo: 'Temperatura',
                          valor: temperatura == null
                              ? '--'
                              : '${temperatura.toStringAsFixed(1)}°C',
                          estado: temperatura == null
                              ? 'Sin lectura'
                              : _estadoTemp(temperatura),
                          colorIcono: FloryColors.warning,
                          esAlerta: temperatura != null &&
                              (temperatura > 28 ||
                                  temperatura < 15),
                        ),

                        // Humedad del aire
                        SensorCard(
                          icono: Icons.water_drop_outlined,
                          titulo: 'Humedad Aire',
                          valor: humedadAire == null
                              ? '--'
                              : '${humedadAire.toStringAsFixed(0)}%',
                          estado: humedadAire == null
                              ? 'Sin lectura'
                              : _estadoHumAire(humedadAire),
                          esAlerta: humedadAire != null &&
                              (humedadAire > 70 ||
                                  humedadAire < 40),
                        ),

                        // Humedad del suelo
                        SensorCard(
                          icono: Icons.grass_rounded,
                          titulo: 'Humedad Suelo',
                          valor: humedadSuelo != null
                              ? '$humedadSuelo%'
                              : humedadSueloADC != null
                                  ? '$humedadSueloADC ADC'
                                  : '--',
                          estado: humedadSuelo != null
                              ? _estadoSuelo(humedadSuelo)
                              : humedadSueloADC != null
                                  ? 'Sin calibrar'
                                  : 'Sin lectura',
                          colorIcono:
                              const Color(0xFF4CAF50),
                          esAlerta: humedadSuelo != null &&
                              humedadSuelo < 30,
                        ),

                        // Riego / Relé
                        SensorCard(
                          icono:
                              Icons.power_settings_new_rounded,
                          titulo: 'Riego / Relé',
                          valor: rele == null
                              ? '--'
                              : rele
                                  ? 'Activo'
                                  : 'Apagado',
                          estado: rele == null
                              ? 'Sin reporte'
                              : rele
                                  ? 'En funcionamiento'
                                  : 'Detenido',
                          colorIcono: rele == true
                              ? FloryColors.accent
                              : FloryColors.textSecondary,
                        ),

                        // NUEVA TARJETA: CALIDAD DEL AIRE
                        SensorCard(
                          icono: Icons.air_rounded,
                          titulo: 'Calidad del aire',
                          valor: _valorAire(calidadAire),
                          estado: _estadoAire(calidadAire),
                          colorIcono: FloryColors.accent,
                          esAlerta: _alertaAire(calidadAire),
                        ),
                      ],
                    ),
                  ),

                  // Última actualización original
                  Center(
                    child: Text(
                      ultimaFecha == null
                          ? 'Sin actualización'
                          : 'Última actualización: '
                              '${_formatHora(ultimaFecha)}',
                      style: const TextStyle(
                        color: FloryColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatHora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
