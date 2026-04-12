import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
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

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
        temperatura: (json['temperatura'] as num).toDouble(),
        humedadAire: (json['humedad_aire'] as num).toDouble(),
        humedadSuelo: (json['humedad_suelo'] as num).toInt(),
        rele: json['rele'] as bool,
        timestamp: DateTime.now(),
      );
}

enum MqttStatus { disconnected, connecting, connected, error }

class MqttService extends ChangeNotifier {
  static const _host = '6bf5f570aacb4000923acf3c45ae3734.s1.eu.hivemq.cloud';
  static const _user = 'Florytech';
  static const _pass = 'Florytech123*';

  static const _topicoSensores = 'sensores/datos';
  static const _topicoReleCmd  = 'sensores/rele';
  static const _topicoReleEst  = 'sensores/rele/estado';

  MqttClient? _client;
  MqttStatus _status = MqttStatus.disconnected;
  MqttStatus get status => _status;

  SensorData? _ultimoDato;
  SensorData? get ultimoDato => _ultimoDato;

  final List<SensorData> historial = [];
  String _errorMsg = '';
  String get errorMsg => _errorMsg;

  Future<void> conectar() async {
    if (_status == MqttStatus.connected || _status == MqttStatus.connecting) return;
    _setStatus(MqttStatus.connecting);

    final clientId = 'FloryTechApp_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // crearCliente usa stub (Android) o web según la plataforma
      _client = crearCliente(_host, clientId);

      _client!.setProtocolV311();
      _client!.keepAlivePeriod      = 30;
      _client!.connectTimeoutPeriod = 10000;
      _client!.logging(on: true);

      _client!.onConnected    = _onConectado;
      _client!.onDisconnected = _onDesconectado;
      _client!.onSubscribed   = (t) => debugPrint('Suscrito a: $t');

      final connMsg = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(_user, _pass)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      _client!.connectionMessage = connMsg;

      await _client!.connect();

      final estado = _client!.connectionStatus;
      if (estado == null || estado.state != MqttConnectionState.connected) {
        debugPrint('Fallo de conexión: ${estado?.returnCode}');
        _errorMsg = estado?.returnCode.toString() ?? 'Error desconocido';
        _setStatus(MqttStatus.error);
        _client!.disconnect();
      }
    } catch (e) {
      _errorMsg = e.toString();
      debugPrint('Error MQTT: $e');
      _setStatus(MqttStatus.error);
      _client?.disconnect();
    }
  }

  void _onConectado() {
    debugPrint('MQTT conectado correctamente');
    _setStatus(MqttStatus.connected);
    _client!.subscribe(_topicoSensores, MqttQos.atLeastOnce);
    _client!.subscribe(_topicoReleEst,  MqttQos.atLeastOnce);

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> mensajes) {
      for (final msg in mensajes) {
        final pub   = msg.payload as MqttPublishMessage;
        final texto = MqttPublishPayload.bytesToStringAsString(pub.payload.message);
        _procesarMensaje(msg.topic, texto);
      }
    });
  }

  void _onDesconectado() {
    debugPrint('MQTT desconectado');
    _setStatus(MqttStatus.disconnected);
    Future.delayed(const Duration(seconds: 5), conectar);
  }

  void _procesarMensaje(String topico, String texto) {
    debugPrint('Mensaje [$topico]: $texto');
    if (topico == _topicoSensores) {
      try {
        final json = jsonDecode(texto) as Map<String, dynamic>;
        final dato = SensorData.fromJson(json);
        _ultimoDato = dato;
        historial.add(dato);
        if (historial.length > 50) historial.removeAt(0);
        notifyListeners();
      } catch (e) {
        debugPrint('Error parseando JSON: $e');
      }
    }
  }

  void setRele(bool estado) {
    if (_status != MqttStatus.connected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(estado ? '1' : '0');
    _client!.publishMessage(_topicoReleCmd, MqttQos.atLeastOnce, builder.payload!);
  }

  void desconectar() => _client?.disconnect();

  void _setStatus(MqttStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }
}
