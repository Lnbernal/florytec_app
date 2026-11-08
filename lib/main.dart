import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FloryTechApp());
}

class FloryTechApp extends StatelessWidget {
  const FloryTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MqttService(),
      child: MaterialApp(
        title: 'FloryTech',
        debugShowCheckedModeBanner: false,
        theme: floryTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
