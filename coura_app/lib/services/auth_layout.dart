import 'package:coura_app/screens/app_loading_screen.dart';
import 'package:coura_app/screens/home_screen.dart';
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
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      final shouldKeep = await authService.value.shouldKeepSession();
      
      if (!shouldKeep) {
        await authService.value.signOut();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: authService,
      builder: (context, authService, child) {
        return StreamBuilder(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            Widget widget;
            if (snapshot.connectionState == ConnectionState.waiting) {
              widget = AppLoadingPage();
            } else if (snapshot.hasData) {
              widget = const HomeScreen();
            } else {
              widget = const LoginScreen();
            }
            return widget;
          },
        );
      },
    );
  }
}
