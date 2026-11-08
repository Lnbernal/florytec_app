import 'package:flutter_test/flutter_test.dart';
import 'package:florytec_app/models/robot_data.dart';

void main() {
  test('Interpreta las lecturas reales del firmware FloryTech Robot', () {
    final dato = RobotData.fromJson({
      'temperatura': 23.8,
      'humedad_aire': 68.0,
      'humedad_suelo': 47,
      'humedad_suelo_raw': 2150,
      'mq135_raw': 1820,
      'distancia_cm': 41.6,
      'modo': 'manual',
      'movimiento': 'detenido',
      'midiendo': false,
      'sonda_abajo': false,
      'timestamp': 1794142800,
    });

    expect(dato.temperatura, 23.8);
    expect(dato.humedadAire, 68.0);
    expect(dato.humedadSuelo, 47);
    expect(dato.mq135Raw, 1820);
    expect(dato.distanciaCm, 41.6);
    expect(dato.modo, 'manual');
    expect(dato.midiendo, false);
    expect(dato.sondaAbajo, false);
    expect(dato.fechaDispositivo, isNotNull);
  });

  test('Tolera mediciones de suelo no realizadas y sonar sin eco', () {
    final dato = RobotData.fromJson({
      'temperatura': null,
      'humedad_aire': null,
      'humedad_suelo': null,
      'humedad_suelo_raw': null,
      'mq135_raw': 950,
      'distancia_cm': null,
      'modo': 'automatico',
      'movimiento': 'detenido',
      'midiendo': true,
      'sonda_abajo': true,
      'timestamp': 0,
    });

    expect(dato.temperatura, isNull);
    expect(dato.humedadSuelo, isNull);
    expect(dato.distanciaCm, isNull);
    expect(dato.midiendo, true);
    expect(dato.fechaDispositivo, isNull);
  });
}
