import 'package:coura_app/screens/app_loading_screen.dart';
import 'package:coura_app/screens/menu_screen.dart';
import 'package:coura_app/services/auth_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:coura_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key});

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> {
  @override
  void initState() {
    super.initState();
    _checkAndClearSession();
  }

  Future<void> _checkAndClearSession() async {
  print("🔹 Revisando sesión actual...");
  final currentUser = FirebaseAuth.instance.currentUser;
  
  if (currentUser != null) {
    print("🔹 Usuario detectado: ${currentUser.email}");
    final shouldKeep = await authService.value.shouldKeepSession();
    print("🔹 shouldKeepSession = $shouldKeep");

    if (!shouldKeep) {
      print("🔹 Cerrando sesión...");
      await authService.value.signOut();
      print("🔹 Sesión cerrada.");
    }
  } else {
    print("🔹 No hay usuario autenticado.");
  }
}


  @override
Widget build(BuildContext context) {
  return ValueListenableBuilder(
    valueListenable: authService,
    builder: (context, value, child) {
      return StreamBuilder<User?>(
        stream: value.authStateChanges,
        builder: (context, snapshot) {
          // Depuración del flujo de autenticación
          debugPrint('Stream connectionState: ${snapshot.connectionState}');
          debugPrint('Stream hasData: ${snapshot.hasData}');
          debugPrint('Stream error: ${snapshot.error}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('Mostrando AppLoadingPage');
            return const AppLoadingPage();
          } else if (snapshot.hasData) {
            debugPrint('Mostrando MenuScreen');
            return const MenuScreen();
          } else {
            debugPrint('Mostrando LoginScreen');
            return const LoginScreen();
          }
        },
      );
    },
  );
}

}
