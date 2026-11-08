import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/mqtt_service.dart';
import '../theme.dart';

/// Antes era un perfil de administrador de demostración. Ahora son opciones
/// operativas reales, porque esta versión no utiliza cuentas de usuario.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(builder: (context, mqtt, _) {
      final conectado = mqtt.status == MqttStatus.connected;
      final robot = mqtt.robotDisponible;
      return SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ajustes', style: TextStyle(color: FloryColors.textPrimary,
              fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Conexiones, almacenamiento e información de FloryTech',
              style: TextStyle(color: FloryColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 24),
          _titulo('Estado de los dispositivos'),
          const SizedBox(height: 10),
          _tarjeta(children: [
            _estado(Icons.cloud_outlined, 'HiveMQ Cloud',
                _estadoMqtt(mqtt.status), conectado),
            const Divider(color: FloryColors.border, height: 22),
            _estado(Icons.smart_toy_outlined, 'Robot móvil',
                robot ? 'En línea · ESP32 transmitiendo' : 'Sin señal reciente del robot', robot),
            const Divider(color: FloryColors.border, height: 22),
            _estado(Icons.wifi_outlined, 'Servidor MQTT',
                mqtt.servidorMqtt, conectado),
            if (mqtt.errorMsg.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(mqtt.errorMsg, style: const TextStyle(
                  color: FloryColors.warning, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reconectar MQTT'),
              onPressed: mqtt.status == MqttStatus.connecting
                  ? null : () => mqtt.reconectar(),
            )),
          ]),
          const SizedBox(height: 22),
          _titulo('Almacenamiento'),
          const SizedBox(height: 10),
          _tarjeta(children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Guardar historial',
                  style: TextStyle(color: FloryColors.textPrimary, fontSize: 14)),
              subtitle: const Text('Conservar lecturas en este dispositivo',
                  style: TextStyle(color: FloryColors.textSecondary, fontSize: 11)),
              value: mqtt.guardarHistorial,
              activeThumbColor: FloryColors.accent,
              onChanged: mqtt.historialCargado
                  ? (valor) => mqtt.configurarGuardadoHistorial(valor)
                  : null,
            ),
            const Divider(color: FloryColors.border),
            _detalle('Invernadero', '${mqtt.historial.length} lecturas guardadas'),
            const SizedBox(height: 8),
            _detalle('Robot', '${mqtt.historialRobot.length} lecturas guardadas'),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Borrar historial local'),
              style: OutlinedButton.styleFrom(foregroundColor: FloryColors.danger),
              onPressed: mqtt.historialCargado
                  ? () => _confirmarBorrado(context, mqtt)
                  : null,
            )),
          ]),
          const SizedBox(height: 22),
          _titulo('Sobre el proyecto'),
          const SizedBox(height: 10),
          _tarjeta(children: [
            _detalle('Aplicación', 'FloryTech · monitoreo y riego IoT'),
            const SizedBox(height: 10),
            _detalle('Robot', 'ESP32 · L298N · SG90 · MQ-135 · DHT22 · HC-SR04'),
            const SizedBox(height: 10),
            _detalle('Comunicación', 'MQTT seguro · HiveMQ Cloud'),
            const SizedBox(height: 10),
            _detalle('Autenticación de la app', 'Desactivada en esta versión'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => showAboutDialog(context: context,
                applicationName: 'FloryTech', applicationVersion: '1.0.0',
                applicationLegalese: 'Proyecto académico de monitoreo agrícola'),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('Acerca de FloryTech'),
            ),
          ]),
          const SizedBox(height: 18),
          const Text('Nota de seguridad: sin inicio de sesión, cualquier persona '
              'con acceso a la aplicación puede utilizar sus controles. '
              'Protege el broker MQTT con credenciales de permisos mínimos; '
              'en Flutter Web, las credenciales incluidas en el cliente son visibles.',
              style: TextStyle(color: FloryColors.textSecondary, fontSize: 11)),
        ]),
      ));
    });
  }

  static String _estadoMqtt(MqttStatus estado) {
    switch (estado) {
      case MqttStatus.connected: return 'Conectado';
      case MqttStatus.connecting: return 'Conectando...';
      case MqttStatus.error: return 'Error de conexión';
      case MqttStatus.disconnected: return 'Desconectado';
    }
  }

  Future<void> _confirmarBorrado(BuildContext context, MqttService mqtt) async {
    final confirmado = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Borrar historial local?'),
        content: const Text('Se eliminarán las lecturas guardadas del invernadero '
            'y del robot en este dispositivo. No se podrán recuperar desde la app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmado == true) {
      await mqtt.limpiarHistorial();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historial local eliminado')),
        );
      }
    }
  }

  Widget _titulo(String titulo) => Text(titulo, style: const TextStyle(
      color: FloryColors.textPrimary, fontSize: 16,
      fontWeight: FontWeight.w700));

  Widget _tarjeta({required List<Widget> children}) => Material(
    color: FloryColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: FloryColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _estado(IconData icono, String nombre, String descripcion, bool bien) {
    return Row(children: [
      Icon(icono, color: bien ? FloryColors.accent : FloryColors.textSecondary,
          size: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nombre, style: const TextStyle(color: FloryColors.textPrimary,
            fontWeight: FontWeight.w600, fontSize: 13)),
        Text(descripcion, style: const TextStyle(
            color: FloryColors.textSecondary, fontSize: 11)),
      ])),
      Icon(bien ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: bien ? FloryColors.accent : FloryColors.textSecondary, size: 16),
    ]);
  }

  Widget _detalle(String titulo, String valor) => Row(children: [
    Text(titulo, style: const TextStyle(
        color: FloryColors.textSecondary, fontSize: 12)),
    const SizedBox(width: 12),
    Expanded(child: Text(valor, textAlign: TextAlign.end,
        style: const TextStyle(color: FloryColors.textPrimary, fontSize: 12))),
  ]);
}
