import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';
import '../widgets/sensor_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final dato  = mqtt.ultimoDato;
        final conectado = mqtt.status == MqttStatus.connected;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mi Invernadero',
                          style: TextStyle(
                            color: FloryColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('Monitoreo en tiempo real',
                          style: TextStyle(color: FloryColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    // Indicador de conexión
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: conectado
                            ? FloryColors.accent.withValues(alpha: 0.12)
                            : FloryColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              color: conectado ? FloryColors.accent : FloryColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mqtt.status == MqttStatus.connecting
                                ? 'Conectando...'
                                : conectado ? 'En línea' : 'Sin conexión',
                            style: TextStyle(
                              color: conectado ? FloryColors.accent : FloryColors.danger,
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
                if (dato == null) ...[
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: FloryColors.accent),
                          const SizedBox(height: 16),
                          Text(
                            conectado
                                ? 'Esperando datos del ESP32...'
                                : 'Conectando al broker MQTT...',
                            style: const TextStyle(color: FloryColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Grid de tarjetas
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                      children: [
                        SensorCard(
                          icono:      Icons.thermostat_rounded,
                          titulo:     'Temperatura',
                          valor:      '${dato.temperatura}°C',
                          estado:     _estadoTemp(dato.temperatura),
                          colorIcono: FloryColors.warning,
                          esAlerta:   dato.temperatura > 28 || dato.temperatura < 15,
                        ),
                        SensorCard(
                          icono:      Icons.water_drop_outlined,
                          titulo:     'Humedad Aire',
                          valor:      '${dato.humedadAire.toStringAsFixed(0)}%',
                          estado:     _estadoHumAire(dato.humedadAire),
                          esAlerta:   dato.humedadAire > 70 || dato.humedadAire < 40,
                        ),
                        SensorCard(
                          icono:      Icons.grass_rounded,
                          titulo:     'Humedad Suelo',
                          valor:      '${dato.humedadSuelo}%',
                          estado:     _estadoSuelo(dato.humedadSuelo),
                          colorIcono: const Color(0xFF4CAF50),
                          esAlerta:   dato.humedadSuelo < 30,
                        ),
                        SensorCard(
                          icono:      Icons.power_settings_new_rounded,
                          titulo:     'Riego / Relé',
                          valor:      dato.rele ? 'Activo' : 'Apagado',
                          estado:     dato.rele ? 'En funcionamiento' : 'Detenido',
                          colorIcono: dato.rele ? FloryColors.accent : FloryColors.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  // Última actualización
                  Center(
                    child: Text(
                      'Última actualización: ${_formatHora(dato.timestamp)}',
                      style: const TextStyle(color: FloryColors.textSecondary, fontSize: 11),
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
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
}
