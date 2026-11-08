import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/mqtt_service.dart';
import '../theme.dart';

/// Historial local de los dos equipos. Los filtros usan fechas reales.
/// Las lecturas se conservan en el navegador o dispositivo que ejecuta la app;
/// esta pantalla no pretende ser un historial en la nube.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _fuente = 0; // 0 = invernadero; 1 = robot
  int _periodo = 0; // 0 = hoy; 1 = 7 dias; 2 = 30 dias

  DateTime _inicioPeriodo(DateTime ahora) {
    if (_periodo == 0) return DateTime(ahora.year, ahora.month, ahora.day);
    return ahora.subtract(Duration(days: _periodo == 1 ? 7 : 30));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(builder: (context, mqtt, _) {
      final ahora = DateTime.now();
      final desde = _inicioPeriodo(ahora);
      final invernadero = mqtt.historial
          .where((e) => !e.timestamp.isBefore(desde) && !e.timestamp.isAfter(ahora))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final robot = mqtt.historialRobot
          .where((e) => !e.fecha.isBefore(desde) && !e.fecha.isAfter(ahora))
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
      final cantidad = _fuente == 0 ? invernadero.length : robot.length;

      return SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Historial', style: TextStyle(
              color: FloryColors.textPrimary, fontSize: 22,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          const Text('Registros guardados en este dispositivo', style: TextStyle(
              color: FloryColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 22),
          _titulo('Origen de las lecturas'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _selector('Invernadero', Icons.eco_outlined, _fuente == 0,
                () => setState(() => _fuente = 0))),
            const SizedBox(width: 10),
            Expanded(child: _selector('Robot', Icons.smart_toy_outlined, _fuente == 1,
                () => setState(() => _fuente = 1))),
          ]),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _filtro('Hoy', 0),
            _filtro('7 días', 1),
            _filtro('30 días', 2),
          ]),
          const SizedBox(height: 18),
          _informacion(cantidad, mqtt.guardarHistorial),
          const SizedBox(height: 16),
          if (!mqtt.historialCargado)
            _mensaje('Cargando registros guardados...')
          else if (cantidad == 0)
            _mensaje(mqtt.guardarHistorial
                ? 'Aún no hay lecturas registradas para este periodo. '
                  'Los datos se guardarán mientras la app esté abierta y conectada.'
                : 'El almacenamiento de historial está desactivado. '
                  'Puedes activarlo desde Ajustes.')
          else if (_fuente == 0) ...[
            _grafica('Temperatura', '°C', Icons.thermostat_rounded,
                FloryColors.warning,
                [for (final d in invernadero)
                  _Lectura(d.timestamp, d.temperatura)]),
            const SizedBox(height: 12),
            _grafica('Humedad ambiental', '%', Icons.water_drop_outlined,
                FloryColors.accent,
                [for (final d in invernadero)
                  _Lectura(d.timestamp, d.humedadAire)]),
            const SizedBox(height: 12),
            _grafica('Humedad del suelo', '%', Icons.grass_outlined,
                const Color(0xFF4CAF50),
                [for (final d in invernadero)
                  _Lectura(d.timestamp, d.humedadSuelo.toDouble())]),
            const SizedBox(height: 20),
            _titulo('Lecturas recientes'),
            const SizedBox(height: 8),
            ...invernadero.reversed.take(6).map((d) => _fila(
                d.timestamp,
                'Temp. ${d.temperatura.toStringAsFixed(1)} °C  ·  '
                'Aire ${d.humedadAire.toStringAsFixed(0)} %  ·  '
                'Suelo ${d.humedadSuelo} %')),
          ] else ...[
            _grafica('Temperatura', '°C', Icons.thermostat_rounded,
                FloryColors.warning,
                [for (final d in robot)
                  _Lectura(d.fecha, d.datos.temperatura)]),
            const SizedBox(height: 12),
            _grafica('Humedad ambiental', '%', Icons.water_drop_outlined,
                FloryColors.accent,
                [for (final d in robot)
                  _Lectura(d.fecha, d.datos.humedadAire)]),
            const SizedBox(height: 12),
            _grafica('Humedad del suelo', '%', Icons.grass_outlined,
                const Color(0xFF4CAF50),
                [for (final d in robot)
                  _Lectura(d.fecha, d.datos.humedadSuelo?.toDouble())]),
            const SizedBox(height: 12),
            _grafica('MQ-135 (ADC)', 'ADC', Icons.air_outlined,
                const Color(0xFF64B5F6),
                [for (final d in robot)
                  _Lectura(d.fecha, d.datos.mq135Raw?.toDouble())]),
            const SizedBox(height: 12),
            _grafica('Distancia frontal', 'cm', Icons.straighten_outlined,
                const Color(0xFFB39DDB),
                [for (final d in robot)
                  _Lectura(d.fecha, d.datos.distanciaCm)]),
            const SizedBox(height: 20),
            _titulo('Lecturas recientes'),
            const SizedBox(height: 8),
            ...robot.reversed.take(6).map((d) => _fila(
                d.fecha,
                'Temp. ${_valor(d.datos.temperatura, '°C')}  ·  '
                'Suelo ${_valor(d.datos.humedadSuelo, '%')}  ·  '
                'MQ-135 ${d.datos.mq135Raw ?? '--'} ADC')),
          ],
          const SizedBox(height: 16),
          const Text('El historial es local y limitado. No se recopilan lecturas '
              'mientras la aplicación está cerrada. Para un histórico continuo '
              'de semanas o meses se necesitará una base de datos o servidor.',
              style: TextStyle(color: FloryColors.textSecondary, fontSize: 11)),
        ]),
      ));
    });
  }

  String _valor(num? n, String unidad) =>
      n == null ? '--' : '${n.toStringAsFixed(n is int ? 0 : 1)} $unidad';

  Widget _titulo(String t) => Text(t, style: const TextStyle(
      color: FloryColors.textPrimary, fontSize: 15,
      fontWeight: FontWeight.w700));

  Widget _selector(String titulo, IconData icono, bool activo, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icono, size: 18),
      label: Text(titulo, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: activo ? FloryColors.accent : FloryColors.textSecondary,
        backgroundColor: activo ? FloryColors.accent.withValues(alpha: 0.12) : FloryColors.card,
        side: BorderSide(color: activo ? FloryColors.accent : FloryColors.border),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      ),
    );
  }

  Widget _filtro(String texto, int indice) {
    final activo = indice == _periodo;
    return ChoiceChip(
      selected: activo,
      label: Text(texto),
      onSelected: (_) => setState(() => _periodo = indice),
      selectedColor: FloryColors.accent.withValues(alpha: 0.25),
      backgroundColor: FloryColors.card,
      labelStyle: TextStyle(
        color: activo ? FloryColors.accent : FloryColors.textSecondary,
        fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: activo ? FloryColors.accent : FloryColors.border),
    );
  }

  Widget _informacion(int cantidad, bool guardando) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FloryColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FloryColors.border),
    ),
    child: Row(children: [
      const Icon(Icons.storage_outlined, color: FloryColors.accent),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$cantidad lecturas en este periodo',
            style: const TextStyle(color: FloryColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13)),
        Text(guardando ? 'Guardado local activado' : 'Guardado local desactivado',
            style: const TextStyle(color: FloryColors.textSecondary, fontSize: 11)),
      ])),
    ]),
  );

  Widget _mensaje(String mensaje) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
    decoration: BoxDecoration(
      color: FloryColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FloryColors.border),
    ),
    child: Column(children: [
      const Icon(Icons.query_stats_rounded, size: 36,
          color: FloryColors.textSecondary),
      const SizedBox(height: 12),
      Text(mensaje, textAlign: TextAlign.center,
          style: const TextStyle(color: FloryColors.textSecondary, fontSize: 13)),
    ]),
  );

  Widget _fila(DateTime fecha, String descripcion) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: FloryColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FloryColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha),
          style: const TextStyle(color: FloryColors.accent, fontSize: 11)),
      const SizedBox(height: 4),
      Text(descripcion, style: const TextStyle(
          color: FloryColors.textPrimary, fontSize: 12)),
    ]),
  );

  Widget _grafica(String titulo, String unidad, IconData icono,
      Color color, List<_Lectura> lecturas) {
    final validas = lecturas.where((e) => e.valor != null && e.valor!.isFinite).toList();
    if (validas.isEmpty) return _mensaje('$titulo: sin lecturas válidas.');
    // Se dibujan como máximo 250 puntos para mantener fluida la aplicación.
    final salto = math.max(1, (validas.length / 250).ceil());
    final dibujadas = <_Lectura>[
      for (var i = 0; i < validas.length; i += salto) validas[i],
    ];
    if (dibujadas.last != validas.last) dibujadas.add(validas.last);
    final primero = dibujadas.first.fecha;
    final spots = <FlSpot>[
      for (final d in dibujadas)
        FlSpot(d.fecha.difference(primero).inSeconds / 60.0, d.valor!),
    ];
    final ys = validas.map((e) => e.valor!).toList();
    final minimo = ys.reduce(math.min);
    final maximo = ys.reduce(math.max);
    final rango = maximo - minimo;
    final margen = rango > 0 ? rango * 0.15 : math.max(1.0, maximo.abs() * 0.05);
    final minY = minimo - margen;
    final maxY = maximo + margen;
    final maxX = math.max(1.0, spots.last.x);
    final fechaInicio = DateFormat('dd/MM HH:mm').format(validas.first.fecha);
    final fechaFin = DateFormat('dd/MM HH:mm').format(validas.last.fecha);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FloryColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FloryColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(titulo, style: const TextStyle(
              color: FloryColors.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w600))),
          Text('${validas.last.valor!.toStringAsFixed(1)} $unidad',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text('$fechaInicio — $fechaFin · ${validas.length} lecturas',
            style: const TextStyle(color: FloryColors.textSecondary,
                fontSize: 10)),
        const SizedBox(height: 18),
        SizedBox(height: 148, child: LineChart(LineChartData(
          minX: 0, maxX: maxX,
          minY: minY, maxY: maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false,
            horizontalInterval: math.max(0.01, (maxY - minY) / 4),
            getDrawingHorizontalLine: (_) => const FlLine(
                color: FloryColors.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 40,
              interval: math.max(0.01, (maxY - minY) / 4),
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                  style: const TextStyle(color: FloryColors.textSecondary,
                      fontSize: 10)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: spots.length == 1),
            belowBarData: BarAreaData(show: true,
                color: color.withValues(alpha: 0.08)),
          )],
        ))),
      ]),
    );
  }
}

class _Lectura {
  final DateTime fecha;
  final double? valor;
  const _Lectura(this.fecha, this.valor);
}
