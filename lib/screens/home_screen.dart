import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'control_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  void _cambiarTab(int nuevo) {
    if (nuevo == _tabIndex) return;
    // Al salir de Control, detiene el robot (también en modo automático).
    if (_tabIndex == 1 && nuevo != 1) {
      context.read<MqttService>().enviarComandoRobot('DETENER');
    }
    setState(() => _tabIndex = nuevo);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MqttService>().conectar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const DashboardScreen(),
      ControlScreen(activo: _tabIndex == 1),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: FloryColors.card,
          border: Border(top: BorderSide(color: FloryColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Inicio',
                    selected: _tabIndex == 0, onTap: () => _cambiarTab(0)),
                _NavItem(icon: Icons.tune_rounded, label: 'Control',
                    selected: _tabIndex == 1, onTap: () => _cambiarTab(1)),
                _NavItem(icon: Icons.show_chart_rounded, label: 'Historial',
                    selected: _tabIndex == 2, onTap: () => _cambiarTab(2)),
                _NavItem(icon: Icons.settings_outlined, label: 'Ajustes',
                    selected: _tabIndex == 3, onTap: () => _cambiarTab(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? FloryColors.accent : FloryColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 4),
              Text(label, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 10,
                  fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
