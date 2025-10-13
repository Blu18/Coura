import 'package:coura_app/screens/login_screen.dart';
import 'package:coura_app/screens/register_activity.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // Importa el servicio

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtiene la información del usuario actual
    final User? user = FirebaseAuth.instance.currentUser;

    void popPage() {
      Navigator.pop(context);
    }

    void logout() async {
      try {
        await authService.value.signOut();
        popPage();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } on FirebaseAuthException catch (e) {
        print(e.message);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Página de Inicio'),
        actions: [
          // Botón para cerrar sesión
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdigris,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterActivity()),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    "Crear Tarea",
                    style: TextStyle(
                      color: Colors.white,
                    ), // Asegúrate de definir el estilo
                  ),
                ],
              ),
            ),
            Text('¡Bienvenido!'),
            const SizedBox(height: 10),
            // Muestra el nombre del usuario si está disponible
            Text(
              user?.displayName ?? 'Usuario',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
