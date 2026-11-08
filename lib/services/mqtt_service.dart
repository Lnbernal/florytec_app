import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/robot_data.dart';
import 'mqtt_client_stub.dart'
    if (dart.library.html) 'mqtt_client_web.dart';

class SensorData {
  final double temperatura;
  final double humedadAire;
  final int humedadSuelo;
  final bool rele;
  final DateTime timestamp;

  SensorData({
    required this.temperatura,
    required this.humedadAire,
    required this.humedadSuelo,
    required this.rele,
    required this.timestamp,
  });

  Map<String, dynamic> toStoredJson() => {
        'temperatura': temperatura,
        'humedad_aire': humedadAire,
        'humedad_suelo': humedadSuelo,
        'rele': rele,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SensorData.fromStoredJson(Map<String, dynamic> json) => SensorData(
        temperatura: (json['temperatura'] as num).toDouble(),
        humedadAire: (json['humedad_aire'] as num).toDouble(),
        humedadSuelo: (json['humedad_suelo'] as num).toInt(),
        rele: json['rele'] == true,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
        temperatura: (json['temperatura'] as num).toDouble(),
        humedadAire: (json['humedad_aire'] as num).toDouble(),
        humedadSuelo: (json['humedad_suelo'] as num).toInt(),
        rele: json['rele'] as bool,
        timestamp: DateTime.now(),
      );
}

/// Lectura móvil con fecha de recepción: no depende del reloj del ESP32.
class RobotHistoryRecord {
  final DateTime fecha;
  final RobotData datos;

  const RobotHistoryRecord({required this.fecha, required this.datos});

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'datos': datos.toJson(),
      };

  factory RobotHistoryRecord.fromJson(Map<String, dynamic> json) =>
      RobotHistoryRecord(
        fecha: DateTime.parse(json['fecha'] as String),
        datos: RobotData.fromJson(json['datos'] as Map<String, dynamic>),
      );
}

enum MqttStatus { disconnected, connecting, connected, error }

/// Gestiona UNA conexión MQTT compartida para el invernadero y el robot.
/// En Flutter Web las credenciales compiladas son visibles: usa una cuenta
/// MQTT con permisos mínimos (ACL) y nunca una cuenta administrativa.
class MqttService extends ChangeNotifier {
  static const _host = '6bf5f570aacb4000923acf3c45ae3734.s1.eu.hivemq.cloud';
  static const _user = String.fromEnvironment('HIVEMQ_USERNAME');
  static const _pass = String.fromEnvironment('HIVEMQ_PASSWORD');

  static const _topicoSensores = 'sensores/datos';
  static const _topicoReleCmd = 'sensores/rele';
  static const _topicoReleEst = 'sensores/rele/estado';

  static const _topicoRobotDatos = 'florytech/robot/datos';
  static const _topicoRobotEstado = 'florytech/robot/estado';
  static const _topicoRobotCmd = 'florytech/robot/comando';

  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _sub;
  Timer? _reconnectTimer;
  Timer? _vigenciaTimer;
  bool _disposed = false;
  bool _reconnectEnabled = false;
  MqttStatus _status = MqttStatus.disconnected;
  MqttStatus get status => _status;

  SensorData? _ultimoDato;
  SensorData? get ultimoDato => _ultimoDato;
  final List<SensorData> historial = [];

  RobotData? _robotDato;
  RobotData? get robotDato => _robotDato;
  String? _robotEstado;
  String? get robotEstado => _robotEstado;
  DateTime? _ultimaLecturaRobot;
  DateTime? get ultimaLecturaRobot => _ultimaLecturaRobot;
  final List<RobotHistoryRecord> historialRobot = [];

  static const _keyHistorialInvernadero = 'florytech_historial_invernadero_v1';
  static const _keyHistorialRobot = 'florytech_historial_robot_v1';
  static const _keyGuardarHistorial = 'florytech_guardar_historial_v1';
  // Una muestra periódica por minuto (más eventos de relé / medición de suelo).
  // Cuando se llena el espacio se conservan muestras antiguas más espaciadas.
  static const int limiteRegistros = 3000;
  static const Duration intervaloHistorial = Duration(minutes: 1);
  SharedPreferences? _prefs;
  late final Future<void> _historialListo;
  Timer? _persistTimer;
  bool _guardarHistorial = true;
  bool get guardarHistorial => _guardarHistorial;
  bool _historialCargado = false;
  bool get historialCargado => _historialCargado;
  String get servidorMqtt => _host;

  Future<void> _cargarHistorial() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final prefs = _prefs!;
      _guardarHistorial = prefs.getBool(_keyGuardarHistorial) ?? true;
      for (final value in prefs.getStringList(_keyHistorialInvernadero) ?? <String>[]) {
        try {
          historial.add(SensorData.fromStoredJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ));
        } catch (e) {
          debugPrint('Lectura local de invernadero descartada: $e');
        }
      }
      for (final value in prefs.getStringList(_keyHistorialRobot) ?? <String>[]) {
        try {
          historialRobot.add(RobotHistoryRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ));
        } catch (e) {
          debugPrint('Lectura local de robot descartada: $e');
        }
      }
      if (historial.length > limiteRegistros) {
        historial.removeRange(0, historial.length - limiteRegistros);
      }
      if (historialRobot.length > limiteRegistros) {
        historialRobot.removeRange(0, historialRobot.length - limiteRegistros);
      }
    } catch (e) {
      debugPrint('No se pudo cargar historial local: $e');
    } finally {
      _historialCargado = true;
      if (!_disposed) notifyListeners();
    }
  }

  void _compactarInvernadero() {
    if (historial.length <= limiteRegistros) return;
    final mitad = historial.length ~/ 2;
    final anteriores = historial.sublist(0, mitad);
    final recientes = historial.sublist(mitad);
    historial.clear();
    for (var i = 0; i < anteriores.length; i += 2) {
      historial.add(anteriores[i]);
    }
    historial.addAll(recientes);
  }

  void _compactarRobot() {
    if (historialRobot.length <= limiteRegistros) return;
    final mitad = historialRobot.length ~/ 2;
    final anteriores = historialRobot.sublist(0, mitad);
    final recientes = historialRobot.sublist(mitad);
    historialRobot.clear();
    for (var i = 0; i < anteriores.length; i += 2) {
      historialRobot.add(anteriores[i]);
    }
    historialRobot.addAll(recientes);
  }

  void _programarGuardado() {
    if (_prefs == null || _persistTimer != null) return;
    _persistTimer = Timer(const Duration(seconds: 3), () {
      _persistTimer = null;
      _persistirHistorial();
    });
  }

  Future<void> _persistirHistorial() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final invernadero = historial.map((e) => jsonEncode(e.toStoredJson())).toList();
    final robot = historialRobot.map((e) => jsonEncode(e.toJson())).toList();
    try {
      await prefs.setStringList(_keyHistorialInvernadero, invernadero);
      await prefs.setStringList(_keyHistorialRobot, robot);
    } catch (e) {
      debugPrint('Error guardando historial local: $e');
    }
  }

  Future<void> configurarGuardadoHistorial(bool activar) async {
    await _historialListo;
    _guardarHistorial = activar;
    notifyListeners();
    await _prefs?.setBool(_keyGuardarHistorial, activar);
  }

  Future<void> limpiarHistorial() async {
    await _historialListo;
    _persistTimer?.cancel();
    _persistTimer = null;
    historial.clear();
    historialRobot.clear();
    notifyListeners();
    await _persistirHistorial();
  }


  String _errorMsg = '';
  String get errorMsg => _errorMsg;

  bool get robotDatosRecientes =>
      _ultimaLecturaRobot != null &&
      DateTime.now().difference(_ultimaLecturaRobot!) <
          const Duration(seconds: 12);

  bool get robotDisponible =>
      _status == MqttStatus.connected &&
      _robotEstado == 'CONECTADO' &&
      robotDatosRecientes;

  bool get robotPuedeMover =>
      robotDisponible &&
      _robotDato != null &&
      _robotDato!.modo == 'manual' &&
      !_robotDato!.midiendo &&
      !_robotDato!.sondaAbajo;

  bool get robotPuedeMedir =>
      robotDisponible &&
      _robotDato != null &&
      !_robotDato!.midiendo &&
      !_robotDato!.sondaAbajo;

  MqttService() {
    _historialListo = _cargarHistorial();
    // Actualiza el estado "sin señal" aunque no lleguen publicaciones nuevas.
    _vigenciaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed && _ultimaLecturaRobot != null) notifyListeners();
    });
  }

  Future<void> conectar() async {
    await _historialListo;
    if (_disposed ||
        _status == MqttStatus.connected ||
        _status == MqttStatus.connecting) {
      return;
    }
    _reconnectEnabled = true;
    _reconnectTimer?.cancel();
    if (_user.isEmpty || _pass.isEmpty) {
      _errorMsg = 'Configura HIVEMQ_USERNAME y HIVEMQ_PASSWORD con --dart-define.';
      _setStatus(MqttStatus.error);
      return;
    }
    _setStatus(MqttStatus.connecting);
    final clientId = 'FloryTechApp_${DateTime.now().microsecondsSinceEpoch}';

    try {
      final client = crearCliente(_host, clientId);
      _client = client;
      client.setProtocolV311();
      client.keepAlivePeriod = 30;
      client.connectTimeoutPeriod = 10000;
      client.logging(on: false);
      client.onConnected = _onConectado;
      client.onDisconnected = _onDesconectado;
      client.onSubscribed = (t) => debugPrint('MQTT suscrito: $t');
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(_user, _pass)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      await client.connect();
      if (_disposed || !_reconnectEnabled) {
        client.disconnect();
        return;
      }
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        _errorMsg = 'Conexión MQTT rechazada: ${client.connectionStatus?.returnCode}';
        _setStatus(MqttStatus.error);
        client.disconnect();
        _programarReconexion();
      }
    } catch (e) {
      _errorMsg = 'Error de conexión MQTT: $e';
      debugPrint(_errorMsg);
      _setStatus(MqttStatus.error);
      _client?.disconnect();
      _programarReconexion();
    }
  }

  void _onConectado() {
    if (_disposed) return;
    _errorMsg = '';
    _setStatus(MqttStatus.connected);
    final client = _client;
    if (client == null) return;
    client.subscribe(_topicoSensores, MqttQos.atLeastOnce);
    client.subscribe(_topicoReleEst, MqttQos.atLeastOnce);
    client.subscribe(_topicoRobotDatos, MqttQos.atMostOnce);
    client.subscribe(_topicoRobotEstado, MqttQos.atLeastOnce);
    _sub?.cancel();
    _sub = client.updates?.listen((mensajes) {
      if (_disposed) return;
      for (final recibido in mensajes) {
        if (recibido.payload is! MqttPublishMessage) continue;
        final pub = recibido.payload as MqttPublishMessage;
        final texto = MqttPublishPayload.bytesToStringAsString(
          pub.payload.message,
        );
        _procesarMensaje(recibido.topic, texto);
      }
    });
  }

  void _onDesconectado() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _robotEstado = null;
    _setStatus(MqttStatus.disconnected);
    if (_reconnectEnabled) _programarReconexion();
  }

  void _programarReconexion() {
    if (_disposed || !_reconnectEnabled) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), conectar);
  }

  void _procesarMensaje(String topico, String texto) {
    if (topico == _topicoSensores) {
      try {
        final dato = SensorData.fromJson(
          jsonDecode(texto) as Map<String, dynamic>,
        );
        _ultimoDato = dato;
        if (_guardarHistorial) {
          final registrar = historial.isEmpty ||
              dato.timestamp.difference(historial.last.timestamp) >= intervaloHistorial ||
              historial.last.rele != dato.rele;
          if (registrar) {
            historial.add(dato);
            _compactarInvernadero();
            _programarGuardado();
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Mensaje de invernadero inválido: $e');
      }
      return;
    }
    if (topico == _topicoRobotEstado) {
      _robotEstado = texto.trim().toUpperCase();
      notifyListeners();
      return;
    }
    if (topico == _topicoRobotDatos) {
      try {
        final dato = RobotData.fromJson(
          jsonDecode(texto) as Map<String, dynamic>,
        );
        _robotDato = dato;
        _ultimaLecturaRobot = DateTime.now();
        if (_guardarHistorial) {
          final ultimo = historialRobot.isEmpty ? null : historialRobot.last;
          final registrar = ultimo == null ||
              _ultimaLecturaRobot!.difference(ultimo.fecha) >= intervaloHistorial ||
              (dato.humedadSueloRaw != null &&
                  dato.humedadSueloRaw != ultimo.datos.humedadSueloRaw);
          if (registrar) {
            historialRobot.add(RobotHistoryRecord(
              fecha: _ultimaLecturaRobot!, datos: dato,
            ));
            _compactarRobot();
            _programarGuardado();
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Mensaje del robot inválido: $e');
      }
    }
  }

  /// Conserva el control original de la bomba, sin cambios de tema o mensaje.
  void setRele(bool estado) {
    if (_status != MqttStatus.connected) return;
    final builder = MqttClientPayloadBuilder()..addString(estado ? '1' : '0');
    _client!.publishMessage(
      _topicoReleCmd,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  /// Comandos no retenidos: no ejecutar órdenes antiguas al reconectar.
  bool enviarComandoRobot(String orden) {
    const permitidos = {
      'ADELANTE', 'ATRAS', 'IZQUIERDA', 'DERECHA',
      'DETENER', 'MANUAL', 'AUTO', 'MEDIR',
    };
    if (!permitidos.contains(orden) ||
        _status != MqttStatus.connected ||
        _client == null) {
      return false;
    }
    if (orden != 'DETENER' && !robotDisponible) return false;
    if ({'ADELANTE', 'ATRAS', 'IZQUIERDA', 'DERECHA'}.contains(orden) &&
        !robotPuedeMover) {
      return false;
    }
    if (orden == 'MEDIR' && !robotPuedeMedir) return false;
    if (orden == 'AUTO' && !robotPuedeMedir) return false;

    try {
      final builder = MqttClientPayloadBuilder()..addString(orden);
      _client!.publishMessage(
        _topicoRobotCmd,
        MqttQos.atMostOnce,
        builder.payload!,
        retain: false,
      );
      return true;
    } catch (e) {
      _errorMsg = 'No se pudo enviar $orden al robot: $e';
      notifyListeners();
      return false;
    }
  }

  /// Desconecta de forma intencional y deja lista una nueva conexión.
  void desconectar() {
    if (_status == MqttStatus.connected) enviarComandoRobot('DETENER');
    _reconnectEnabled = false;
    _reconnectTimer?.cancel();
    final anterior = _client;
    // Evita que un callback tardío de la conexión anterior cambie el estado.
    if (anterior != null) {
      anterior.onConnected = null;
      anterior.onDisconnected = null;
      anterior.disconnect();
    }
    _sub?.cancel();
    _sub = null;
    _client = null;
    _robotEstado = null;
    _setStatus(MqttStatus.disconnected);
  }

  Future<void> reconectar() async {
    desconectar();
    await conectar();
  }

  void _setStatus(MqttStatus nuevo) {
    if (_disposed) return;
    _status = nuevo;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectEnabled = false;
    _reconnectTimer?.cancel();
    _vigenciaTimer?.cancel();
    _persistTimer?.cancel();
    _persistirHistorial();
    _sub?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
