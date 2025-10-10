import 'package:coura_app/screens/app_loading_screen.dart';
import 'package:coura_app/screens/home_screen.dart';
import 'package:coura_app/services/auth_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:coura_app/screens/login_screen.dart';
import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, this.pageIfNotConnected});

  final Widget? pageIfNotConnected;

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
              widget =  AppLoadingPage();
            } else if (snapshot.hasData) {
              widget = const HomeScreen();
            } else {
              widget = pageIfNotConnected ?? const LoginScreen();
            }
            return widget;
          },
        );
      },
    );
  }
}
