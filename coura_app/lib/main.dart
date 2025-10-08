import 'package:coura_app/screens/login_screen.dart';
import 'package:coura_app/screens/register_screen.dart';
import 'package:flutter/material.dart';

void main() async {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      //home: LoginScreen(),
      home: RegisterScreen(),
    );
  }
}

