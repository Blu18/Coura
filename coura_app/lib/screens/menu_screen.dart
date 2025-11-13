import 'package:coura_app/screens/chat_ia_screen.dart';
import 'package:coura_app/screens/home_screen.dart';
import 'package:coura_app/screens/pending_task_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreen();
}

class _MenuScreen extends State<MenuScreen> {
  int _selectedIndex = 0;
  final User user = FirebaseAuth.instance.currentUser!;
  late final List<Widget> _screens;

   @override
  void initState() {
    super.initState();
    // Inicializar aquí donde ya tienes acceso a user
    _screens = [
      HomeScreen(),
      PendingTaskScreen(),
      ChatIAScreen(
        userId: user.uid, 
        geminiApiKey: dotenv.env["GEMINI_API_KEY"] ?? "",
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Muestra la pantalla seleccionada
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_rounded),
            label: "Tareas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: "Chat",
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,   // Oculta labels si prefieres
        showUnselectedLabels: false,
      ),
    );
  }
}