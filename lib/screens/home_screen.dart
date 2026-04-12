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

  final _tabs = const [
    DashboardScreen(),
    ControlScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Iniciar conexión MQTT al entrar al home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MqttService>().conectar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FloryColors.card,
          border: Border(top: BorderSide(color: FloryColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded,      label: 'Inicio',   index: 0, selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
                _NavItem(icon: Icons.tune_rounded,       label: 'Control',  index: 1, selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
                _NavItem(icon: Icons.show_chart_rounded, label: 'Historial',index: 2, selected: _tabIndex == 2, onTap: () => setState(() => _tabIndex = 2)),
                _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil', index: 3, selected: _tabIndex == 3, onTap: () => setState(() => _tabIndex = 3)),
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
  final String   label;
  final int      index;
  final bool     selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? FloryColors.accent : FloryColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
