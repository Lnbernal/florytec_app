import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/robot_data.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';

/// Panel integrado en Control, no una pestaña de navegación independiente.
/// Las órdenes son MQTT sin retención, con repetición solo mientras se pulsa.
class RobotScreen extends StatefulWidget {
  final bool activo;
  final bool integrado;
  const RobotScreen({super.key, required this.activo, this.integrado = false});

  @override
  State<RobotScreen> createState() => _RobotScreenState();
}

class _RobotScreenState extends State<RobotScreen>
    with WidgetsBindingObserver {
  MqttService? _mqtt;
  Timer? _repeticion;
  String? _direccion;
  DateTime? _comandoPendienteHasta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mqtt ??= context.read<MqttService>();
  }

  @override
  void didUpdateWidget(covariant RobotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activo && !widget.activo) {
      _detenerYSalir();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _detenerYSalir();
  }

  /// Se envía una orden cada 400 ms para alimentar el timeout de 1,7 s del ESP32.
  /// Con pérdida de conexión, el firmware se detiene por seguridad.
  void _empezarDireccion(String orden) {
    final mqtt = _mqtt;
    if (!widget.activo || mqtt == null || !mqtt.robotPuedeMover ||
        _direccion != null || _esperandoConfirmacion) {
      return;
    }
    if (!mqtt.enviarComandoRobot(orden)) return;
    _direccion = orden;
    _repeticion?.cancel();
    _repeticion = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!widget.activo || !mqtt.robotPuedeMover || !mounted) {
        _soltarDireccion();
        return;
      }
      if (!mqtt.enviarComandoRobot(orden)) _soltarDireccion();
    });
    if (mounted) setState(() {});
  }

  void _soltarDireccion() {
    _repeticion?.cancel();
    _repeticion = null;
    if (_direccion != null) {
      _direccion = null;
      _mqtt?.enviarComandoRobot('DETENER');
      if (mounted) setState(() {});
    }
  }

  void _detenerYSalir() {
    _soltarDireccion();
    // También detiene el modo semiautónomo al ocultar la pantalla.
    _mqtt?.enviarComandoRobot('DETENER');
  }

  bool get _esperandoConfirmacion =>
      _comandoPendienteHasta != null &&
      DateTime.now().isBefore(_comandoPendienteHasta!);

  void _enviar(String comando) {
    final mqtt = _mqtt;
    if (mqtt == null) return;
    _soltarDireccion();
    if (!mqtt.enviarComandoRobot(comando)) return;
    if (comando == 'AUTO' || comando == 'MANUAL' || comando == 'MEDIR') {
      _comandoPendienteHasta = DateTime.now().add(
        const Duration(seconds: 3),
      );
    } else {
      _comandoPendienteHasta = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repeticion?.cancel();
    _mqtt?.enviarComandoRobot('DETENER');
    super.dispose();
  }

  String _numero(num? value, {int decimales = 1, String unidad = ''}) =>
      value == null ? '--' : '${value.toStringAsFixed(decimales)}$unidad';

  String _hora(DateTime fecha) =>
      '${fecha.hour.toString().padLeft(2, '0')}:'
      '${fecha.minute.toString().padLeft(2, '0')}:'
      '${fecha.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final dato = mqtt.robotDato;
        final disponible = mqtt.robotDisponible;
        final auto = dato?.modo == 'automatico';
        final ocupado = dato?.midiendo == true || dato?.sondaAbajo == true;
        final manualHabilitado =
            widget.activo && mqtt.robotPuedeMover && !_esperandoConfirmacion;
        final distancia = dato?.distanciaCm;
        final obstaculo = distancia != null && distancia <= 25;

        return widget.integrado
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: _contenidoPanel(mqtt, dato, disponible, auto, ocupado,
                  manualHabilitado, distancia, obstaculo),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
                children: _contenidoPanel(mqtt, dato, disponible, auto, ocupado,
                    manualHabilitado, distancia, obstaculo),
              ),
            );
      },
    );
  }

  List<Widget> _contenidoPanel(MqttService mqtt, RobotData? dato,
      bool disponible, bool auto, bool ocupado, bool manualHabilitado,
      double? distancia, bool obstaculo) => [
              const Text('Mi Robot', style: TextStyle(
                color: FloryColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 4),
              const Text('Monitoreo y control de orugas', style: TextStyle(
                color: FloryColors.textSecondary, fontSize: 12,
              )),
              const SizedBox(height: 18),
              _estadoConexion(mqtt, disponible, dato),
              const SizedBox(height: 20),
              _titulo('Lecturas del robot'),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                const espacio = 10.0;
                final ancho = constraints.maxWidth < 430
                    ? (constraints.maxWidth - espacio) / 2
                    : (constraints.maxWidth - (2 * espacio)) / 3;
                return Wrap(
                  spacing: espacio,
                  runSpacing: espacio,
                  children: [
                    _tarjetaMetrica(ancho, Icons.thermostat_outlined,
                        'Temperatura', _numero(dato?.temperatura, unidad: ' °C'),
                        'DHT22'),
                    _tarjetaMetrica(ancho, Icons.water_drop_outlined,
                        'Humedad aire', _numero(dato?.humedadAire,
                            decimales: 0, unidad: ' %'), 'DHT22'),
                    _tarjetaMetrica(ancho, Icons.grass_outlined,
                        'Humedad suelo', dato?.humedadSuelo == null
                            ? '--' : '${dato!.humedadSuelo} %',
                        'Última medición de sonda'),
                    _tarjetaMetrica(ancho, Icons.air_outlined,
                        'MQ-135', dato?.mq135Raw == null
                            ? '--' : '${dato!.mq135Raw}',
                        'Lectura ADC (0–4095), no PPM'),
                    _tarjetaMetrica(ancho, Icons.straighten_outlined,
                        'Distancia', _numero(dato?.distanciaCm,
                            unidad: ' cm'), 'Ultrasonido HC-SR04'),
                    _tarjetaMetrica(ancho, Icons.precision_manufacturing_outlined,
                        'Sonda SG90', ocupado ? 'Activa' : 'Recogida',
                        ocupado ? 'Medición en proceso' : 'Lista para medir'),
                  ],
                );
              }),
              const SizedBox(height: 14),
              if (obstaculo && distancia != null) _avisoObstaculo(distancia),
              const SizedBox(height: 16),
              _titulo('Modo de operación'),
              const SizedBox(height: 10),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(auto ? Icons.smart_toy_rounded : Icons.gamepad_rounded,
                          color: FloryColors.accent, size: 25),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auto ? 'Semiautónomo' : 'Manual',
                            style: const TextStyle(
                              color: FloryColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            )),
                          Text(dato == null
                              ? 'Esperando estado del ESP32'
                              : 'Movimiento: ${dato.movimiento}',
                            style: const TextStyle(
                              color: FloryColors.textSecondary, fontSize: 12,
                            )),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _accion(
                        'Manual', Icons.pan_tool_alt_outlined,
                        !auto ? null : (disponible && !ocupado)
                            ? () => _enviar('MANUAL') : null,
                        principal: !auto,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _accion(
                        'Auto', Icons.auto_mode_outlined,
                        auto ? null : (disponible && !ocupado)
                            ? () => _enviar('AUTO') : null,
                        principal: auto,
                      )),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'En automático, el ESP32 avanza y gira ante obstáculos. '
                      'Mantén supervisión visual y prueba primero con las orugas levantadas.',
                      style: TextStyle(
                        color: FloryColors.textSecondary, fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _titulo('Control de las orugas'),
              const SizedBox(height: 10),
              _panel(
                child: Column(children: [
                  Text(auto
                      ? 'Para conducir, cambia primero a modo manual.'
                      : 'Mantén presionada una dirección. Suelta para detener.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: FloryColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _botonDireccion('ADELANTE', Icons.keyboard_arrow_up_rounded,
                      manualHabilitado),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _botonDireccion('IZQUIERDA', Icons.keyboard_arrow_left_rounded,
                        manualHabilitado),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      height: 75,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FloryColors.danger,
                          foregroundColor: FloryColors.background,
                          padding: const EdgeInsets.all(4),
                        ),
                        onPressed: mqtt.status == MqttStatus.connected
                            ? () => _enviar('DETENER') : null,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stop_circle_outlined, size: 26),
                            SizedBox(height: 3),
                            Text('DETENER', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _botonDireccion('DERECHA', Icons.keyboard_arrow_right_rounded,
                        manualHabilitado),
                  ]),
                  const SizedBox(height: 10),
                  _botonDireccion('ATRAS', Icons.keyboard_arrow_down_rounded,
                      manualHabilitado),
                  const SizedBox(height: 14),
                  const Text(
                    'L298N: ENA y ENB con jumpers instalados. '
                    'La velocidad no se ajusta por PWM.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: FloryColors.textSecondary, fontSize: 11,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              _titulo('Medición del suelo'),
              const SizedBox(height: 10),
              _panel(child: Row(children: [
                const Icon(Icons.science_outlined,
                    size: 28, color: FloryColors.accent),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ocupado ? 'Sonda en movimiento' : 'Sonda recogida',
                      style: const TextStyle(
                        color: FloryColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text('Servo SG90 · lectura de suelo',
                      style: TextStyle(
                        color: FloryColors.textSecondary, fontSize: 11,
                      ),
                    ),
                  ],
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.activo && mqtt.robotPuedeMedir &&
                      !_esperandoConfirmacion
                      ? () => _enviar('MEDIR') : null,
                  child: const Text('Medir'),
                ),
              ])),
              const SizedBox(height: 18),
              Center(child: Text(
                dato?.fechaDispositivo == null
                    ? 'Sin registros del robot'
                    : 'Último registro: ${_hora(dato!.fechaDispositivo!)}',
                style: const TextStyle(
                    color: FloryColors.textSecondary, fontSize: 11),
              )),
  ];


  Widget _titulo(String texto) => Text(texto,
      style: const TextStyle(
        color: FloryColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 17,
      ));

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FloryColors.card,
      border: Border.all(color: FloryColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _estadoConexion(MqttService mqtt, bool disponible, RobotData? dato) {
    String subtitulo;
    if (mqtt.status == MqttStatus.connecting) {
      subtitulo = 'Conectando a HiveMQ Cloud...';
    } else if (mqtt.status != MqttStatus.connected) {
      subtitulo = 'Sin conexión con HiveMQ Cloud';
    } else if (!disponible) {
      subtitulo = 'Broker conectado; esperando datos recientes del ESP32';
    } else {
      subtitulo = 'Robot conectado y transmitiendo';
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF103B33), FloryColors.cardLight],
        ),
        border: Border.all(color: FloryColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.precision_manufacturing_rounded,
            color: FloryColors.accent, size: 32),
          const SizedBox(width: 12),
          const Expanded(child: Text('FloryTech Robot',
            style: TextStyle(
              color: FloryColors.textPrimary, fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          )),
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: disponible ? FloryColors.accent : FloryColors.danger,
              shape: BoxShape.circle,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(subtitulo, style: const TextStyle(
          color: FloryColors.textPrimary, fontSize: 13,
        )),
        const SizedBox(height: 4),
        Text('Estado del ESP32: ${mqtt.robotEstado ?? 'sin reporte'}',
          style: const TextStyle(
            color: FloryColors.textSecondary, fontSize: 12,
          )),
        if (mqtt.status == MqttStatus.error && mqtt.errorMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(mqtt.errorMsg, style: const TextStyle(
            color: FloryColors.warning, fontSize: 12,
          )),
        ],
      ]),
    );
  }

  Widget _tarjetaMetrica(double width, IconData icono, String titulo,
      String valor, String nota) => SizedBox(
    width: width,
    height: 136,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FloryColors.card,
        border: Border.all(color: FloryColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, size: 21, color: FloryColors.accent),
        const SizedBox(height: 7),
        Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FloryColors.textSecondary, fontSize: 11,
          )),
        const SizedBox(height: 2),
        Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FloryColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          )),
        const Spacer(),
        Text(nota, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FloryColors.textSecondary, fontSize: 10,
          )),
      ]),
    ),
  );

  Widget _avisoObstaculo(double cm) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FloryColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FloryColors.warning.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: FloryColors.warning),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Obstáculo frontal a ${cm.toStringAsFixed(1)} cm. '
        'No se permite avanzar.',
        style: const TextStyle(
            color: FloryColors.warning, fontSize: 12),
      )),
    ]),
  );

  Widget _accion(String texto, IconData icono, VoidCallback? accion,
      {required bool principal}) => SizedBox(
    height: 43,
    child: OutlinedButton.icon(
      onPressed: accion,
      icon: Icon(icono, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            principal ? FloryColors.background : FloryColors.accent,
        backgroundColor: principal ? FloryColors.accent : FloryColors.cardLight,
        side: const BorderSide(color: FloryColors.accentDark),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _botonDireccion(String comando, IconData icono, bool habilitado) {
    final pulsado = _direccion == comando;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: habilitado ? (_) => _empezarDireccion(comando) : null,
      onTapUp: (_) => _soltarDireccion(),
      onTapCancel: _soltarDireccion,
      child: Container(
        width: 90,
        height: 75,
        decoration: BoxDecoration(
          color: pulsado
              ? FloryColors.accent.withValues(alpha: 0.25)
              : FloryColors.cardLight,
          border: Border.all(
            color: pulsado ? FloryColors.accent : FloryColors.border,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icono, size: 30,
            color: habilitado ? FloryColors.accent : FloryColors.textSecondary),
          const SizedBox(height: 2),
          Text(comando, style: TextStyle(
            color: habilitado ? FloryColors.textPrimary : FloryColors.textSecondary,
            fontSize: 10, fontWeight: FontWeight.w600,
          )),
        ]),
      ),
    );
  }
}
