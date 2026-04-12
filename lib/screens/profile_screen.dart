import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        final conectado = mqtt.status == MqttStatus.connected;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Avatar
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FloryColors.accent.withOpacity(0.15),
                    border: Border.all(color: FloryColors.accent.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.person_rounded,
                    color: FloryColors.accent, size: 40),
                ),
                const SizedBox(height: 12),
                const Text('Administrador',
                  style: TextStyle(
                    color: FloryColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text('admin@florytec.com',
                  style: TextStyle(color: FloryColors.textSecondary, fontSize: 13)),

                const SizedBox(height: 32),

                // Estado MQTT
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FloryColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: conectado
                          ? FloryColors.accent.withOpacity(0.2)
                          : FloryColors.danger.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        conectado ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: conectado ? FloryColors.accent : FloryColors.danger,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Broker MQTT',
                            style: TextStyle(color: FloryColors.textPrimary,
                              fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            conectado ? 'HiveMQ Cloud — Conectado' : 'Desconectado',
                            style: TextStyle(
                              color: conectado ? FloryColors.accent : FloryColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (!conectado)
                        GestureDetector(
                          onTap: () => mqtt.conectar(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: FloryColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Reconectar',
                              style: TextStyle(color: FloryColors.accent,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Opciones
                _GrupoOpciones(
                  titulo: 'Configuración',
                  items: [
                    _OpcionItem(
                      icono: Icons.person_outline_rounded,
                      label: 'Editar perfil',
                      onTap: () {},
                    ),
                    _OpcionItem(
                      icono: Icons.notifications_outlined,
                      label: 'Notificaciones',
                      onTap: () {},
                    ),
                    _OpcionItem(
                      icono: Icons.wifi_rounded,
                      label: 'Configurar broker MQTT',
                      onTap: () {},
                    ),
                    _OpcionItem(
                      icono: Icons.info_outline_rounded,
                      label: 'Acerca de FloryTech',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'FloryTech',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2024 FloryTech',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Botón cerrar sesión
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FloryColors.danger.withOpacity(0.15),
                      foregroundColor: FloryColors.danger,
                      side: BorderSide(color: FloryColors.danger.withOpacity(0.3)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                    onPressed: () {
                      mqtt.desconectar();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GrupoOpciones extends StatelessWidget {
  final String titulo;
  final List<_OpcionItem> items;
  const _GrupoOpciones({required this.titulo, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FloryColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FloryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(titulo,
              style: const TextStyle(
                color: FloryColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...items.map((item) => Column(
            children: [
              const Divider(height: 1, color: FloryColors.border),
              item,
            ],
          )),
        ],
      ),
    );
  }
}

class _OpcionItem extends StatelessWidget {
  final IconData icono;
  final String   label;
  final VoidCallback onTap;
  const _OpcionItem({required this.icono, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono, color: FloryColors.textSecondary, size: 20),
      title: Text(label,
        style: const TextStyle(color: FloryColors.textPrimary, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right_rounded,
        color: FloryColors.textSecondary, size: 20),
      onTap: onTap,
      dense: true,
    );
  }
}
