import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filtro = 0; // 0=Hoy, 1=Semana, 2=Mes

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final datos = mqtt.historial;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historial',
                  style: TextStyle(
                    color: FloryColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Lecturas de sesión actual',
                  style: TextStyle(color: FloryColors.textSecondary, fontSize: 12)),

                const SizedBox(height: 20),

                // Filtros
                Row(
                  children: ['Hoy', 'Semana', 'Mes'].asMap().entries.map((e) {
                    final sel = _filtro == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _filtro = e.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? FloryColors.accent.withOpacity(0.15) : FloryColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? FloryColors.accent : FloryColors.border,
                          ),
                        ),
                        child: Text(e.value,
                          style: TextStyle(
                            color: sel ? FloryColors.accent : FloryColors.textSecondary,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                if (datos.isEmpty)
                  Container(
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FloryColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Sin datos aún. Esperando lecturas...',
                      style: TextStyle(color: FloryColors.textSecondary)),
                  )
                else ...[
                  // Gráfica de Temperatura
                  _GraficaCard(
                    titulo:  'Temperatura (°C)',
                    icono:   Icons.thermostat_rounded,
                    color:   FloryColors.warning,
                    puntos:  datos.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.temperatura)).toList(),
                    minY: 10, maxY: 40,
                  ),

                  const SizedBox(height: 16),

                  // Gráfica de Humedad Aire
                  _GraficaCard(
                    titulo:  'Humedad Aire (%)',
                    icono:   Icons.water_drop_outlined,
                    color:   FloryColors.accent,
                    puntos:  datos.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.humedadAire)).toList(),
                    minY: 0, maxY: 100,
                  ),

                  const SizedBox(height: 16),

                  // Gráfica de Humedad Suelo
                  _GraficaCard(
                    titulo:  'Humedad Suelo (%)',
                    icono:   Icons.grass_rounded,
                    color:   const Color(0xFF4CAF50),
                    puntos:  datos.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.humedadSuelo.toDouble())).toList(),
                    minY: 0, maxY: 100,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GraficaCard extends StatelessWidget {
  final String     titulo;
  final IconData   icono;
  final Color      color;
  final List<FlSpot> puntos;
  final double     minY;
  final double     maxY;

  const _GraficaCard({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.puntos,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FloryColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FloryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 18),
              const SizedBox(width: 8),
              Text(titulo,
                style: const TextStyle(
                  color: FloryColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: FloryColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY - minY) / 4,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(color: FloryColors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: puntos,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
