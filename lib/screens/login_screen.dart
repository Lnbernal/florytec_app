import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _verPass    = false;
  bool _cargando   = false;

  void _login() async {
    setState(() => _cargando = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _cargando = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Logo
              Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: FloryColors.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: FloryColors.accent.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.eco_rounded,
                      color: FloryColors.accent, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('FloryTech',
                    style: TextStyle(
                      color: FloryColors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Gestión inteligente de invernaderos',
                    style: TextStyle(color: FloryColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 56),

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: FloryColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passCtrl,
                obscureText: !_verPass,
                style: const TextStyle(color: FloryColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: FloryColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('¿Olvidaste tu contraseña?',
                    style: TextStyle(color: FloryColors.textSecondary, fontSize: 13)),
                ),
              ),

              const SizedBox(height: 20),

              // Botón login
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _login,
                  child: _cargando
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FloryColors.background,
                          ))
                      : const Text('Iniciar Sesión'),
                ),
              ),

              const SizedBox(height: 48),
              const Text('© 2024 FloryTech',
                textAlign: TextAlign.center,
                style: TextStyle(color: FloryColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
