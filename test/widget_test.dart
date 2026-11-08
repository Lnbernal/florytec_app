
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:florytec_app/screens/home_screen.dart';
import 'package:florytec_app/services/mqtt_service.dart';
import 'package:florytec_app/theme.dart';

// Simula MQTT sin conectarse realmente a HiveMQ.
class MqttServicePrueba extends MqttService {
  @override
  Future<void> conectar() async {
    // No abrir conexiones durante las pruebas.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FloryTech muestra las secciones principales',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Simula una pantalla de escritorio.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mqtt = MqttServicePrueba();

    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<MqttService>.value(
          value: mqtt,
          child: MaterialApp(
            theme: floryTheme(),
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      mqtt.dispose();
    }
  });
}