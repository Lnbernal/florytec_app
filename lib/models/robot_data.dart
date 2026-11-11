/// Modelo de los mensajes JSON que publica FloryTech_Robot_ESP32.ino.
/// Los campos pueden venir en null mientras un sensor no tiene lectura.
class RobotData {
  final double? temperatura;
  final double? humedadAire;
  final int? humedadSuelo;
  final int? humedadSueloRaw;
  final int? mq135Raw;
  final double? distanciaCm;
  final String modo;
  final String movimiento;
  final bool midiendo;
  final bool sondaAbajo;
  final DateTime? fechaDispositivo;

  const RobotData({
    required this.temperatura,
    required this.humedadAire,
    required this.humedadSuelo,
    required this.humedadSueloRaw,
    required this.mq135Raw,
    required this.distanciaCm,
    required this.modo,
    required this.movimiento,
    required this.midiendo,
    required this.sondaAbajo,
    required this.fechaDispositivo,
  });

  /// Mismos nombres de campos que usa el firmware para guardar lecturas locales.
  Map<String, dynamic> toJson() => {
        'temperatura': temperatura,
        'humedad_aire': humedadAire,
        'humedad_suelo': humedadSuelo,
        'humedad_suelo_raw': humedadSueloRaw,
        'mq135_raw': mq135Raw,
        'distancia_cm': distanciaCm,
        'modo': modo,
        'movimiento': movimiento,
        'midiendo': midiendo,
        'sonda_abajo': sondaAbajo,
        'timestamp': fechaDispositivo == null ? null :
            fechaDispositivo!.toUtc().millisecondsSinceEpoch ~/ 1000,
      };

  static double? _decimal(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _entero(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _booleano(dynamic value) =>
      value == true || value == 1 || value == 'true';

  factory RobotData.fromJson(Map<String, dynamic> json) {
    final fechaUnix = _entero(json['timestamp']);
    return RobotData(
      temperatura: _decimal(json['temperatura']),
      humedadAire: _decimal(json['humedad_aire']),
      humedadSuelo: _entero(json['humedad_suelo']),
      
      humedadSueloRaw: _entero(
        json['humedad_suelo_raw'] ?? json['humedad_suelo_adc'],
      ),
      mq135Raw: _entero(
        json['mq135_raw'] ?? json['calidad_aire_adc'],
      ),
      distanciaCm: _decimal(
        json['distancia_cm'] ?? json['distancia'],
      ),

      modo: json['modo']?.toString() ?? 'desconocido',
      movimiento: json['movimiento']?.toString() ?? 'detenido',
      midiendo: _booleano(json['midiendo']),
      sondaAbajo: _booleano(json['sonda_abajo']),
      fechaDispositivo: fechaUnix == null || fechaUnix < 1600000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              fechaUnix * 1000,
              isUtc: true,
            ).toLocal(),
    );
  }
}
