
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient crearCliente(String host, String clientId) {
  final client = MqttBrowserClient(
    'wss://$host/mqtt',
    clientId,
  );

  client.port = 8884;
  client.websocketProtocols =
      MqttClientConstants.protocolsSingleDefault;

  return client;
}
