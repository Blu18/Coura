import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/screens/chat_ia_screen.dart';
import 'package:coura_app/screens/login_screen.dart';
import 'package:coura_app/screens/pending_task_screen.dart';
import 'package:coura_app/screens/register_activity.dart';
import 'package:coura_app/screens/sync_assignments.dart';
import 'package:coura_app/services/auth_service.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Clase wrapper para manejar AppBars personalizados
class _ScreenConfig {
  final Widget screen;
  final PreferredSizeWidget? customAppBar;

  _ScreenConfig({required this.screen, this.customAppBar});
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreen();
}

class _MenuScreen extends State<MenuScreen> {
  int _selectedIndex = 0;
  final User user = FirebaseAuth.instance.currentUser!;
  late final List<_ScreenConfig> _screens;

  Future<void> _limpiarChat() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar conversación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar todos los mensajes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final mensajes = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('chat_mensajes')
            .get();

        final batch = firestore.batch();
        for (var doc in mensajes.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversación eliminada')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar mensajes')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      _ScreenConfig(
        screen: ChatIAScreen(
          userId: user.uid,
          geminiApiKey: dotenv.env["GEMINI_API_KEY"] ?? "",
        ),
        customAppBar: AppBar(
        title: Text(
          'Asistente',
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _limpiarChat,
            tooltip: 'Limpiar conversación',
          ),
        ],
      ),
      ),
      _ScreenConfig(
        screen: PendingTaskScreen(),
        customAppBar: AppBar(
          title: Text('Tareas Pendientes', style: CTextStyle.headlineLarge),
          backgroundColor: AppColors.lapizlazuli,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.add_circle,
                color: AppColors.lightgreen,
                size: 35,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterActivity()),
                );
              },
            ),
          ],
        ),
      ),
      _ScreenConfig(screen: SyncAssignments()),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }

  PreferredSizeWidget _getAppBar() {
    final currentConfig = _screens[_selectedIndex];

    // Si tiene un AppBar personalizado, úsalo
    if (currentConfig.customAppBar != null) {
      return currentConfig.customAppBar!;
    }

    // AppBar por defecto
    return AppBar(
      title: Text(_getTitle(), style: CTextStyle.headlineLarge),
      backgroundColor: AppColors.lapizlazuli,
      foregroundColor: Colors.white,
      centerTitle: true,
    );
  }

  void logout() async {
    try {
      await authService.value.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      drawer: Drawer(
        backgroundColor: const Color.fromARGB(255, 106, 173, 224),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(height: 50),
            ListTile(
              leading: Icon(Icons.chat_bubble_rounded, color: Colors.white),
              title: Text(
                'Asistente',
                style: CTextStyle.tittleLarge.copyWith(color: Colors.white),
              ),
              selected: _selectedIndex == 0,
              selectedTileColor: const Color.fromARGB(255, 39, 129, 197),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: Icon(Icons.menu_rounded, color: Colors.white),
              title: Text(
                'Tareas',
                style: CTextStyle.tittleLarge.copyWith(color: Colors.white),
              ),
              selected: _selectedIndex == 1,
              selectedTileColor: const Color.fromARGB(255, 39, 129, 197),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: Icon(Icons.home_rounded, color: Colors.white),
              title: Text(
                'Perfil',
                style: CTextStyle.tittleLarge.copyWith(color: Colors.white),
              ),
              selected: _selectedIndex == 2,
              selectedTileColor: const Color.fromARGB(255, 39, 129, 197),
              onTap: () => _onItemTapped(2),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Cerrar sesión',
                style: CTextStyle.tittleLarge.copyWith(color: Colors.white),
              ),
              onTap: logout,
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex].screen,
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Asistente';
      case 1:
        return 'Tareas Pendientes';
      case 2:
        return 'Perfil';
      default:
        return 'Coura App';
    }
  }
}
