import 'package:coura_app/screens/register_activity.dart';
import 'package:coura_app/screens/sync_assignments.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User user = FirebaseAuth.instance.currentUser!;
  @override
  void initState() {
    super.initState();
    authService.value.syncClassroomData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdigris,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SyncAssignments()),
                );
              },
              child: Text(
                'Sincronizar con Classroom',
                style: CTextStyle.bodyMediuimbold.copyWith(color: Colors.white),
              ),
            ),

            Text('¡Bienvenido!'),
            const SizedBox(height: 10),
            // Muestra el nombre del usuario si está disponible
            Text(
              user.displayName ?? 'Usuario',
              style: CTextStyle.bodyMediuimbold.copyWith(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
