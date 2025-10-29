import 'package:coura_app/services/auth_service.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SyncAssignments extends StatefulWidget {
  const SyncAssignments({super.key});

  @override
  State<SyncAssignments> createState() => _SyncAssignmentsState();
}

class _SyncAssignmentsState extends State<SyncAssignments> {
  GoogleSignInAccount? googleUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Sincronizar Asignaciones",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Acceso Requerido a Classroom",
              style: CTextStyle.headlineLarge.copyWith(
                color: AppColors.indigodye,
              ),
            ),

            SizedBox(height: 25),
            Text(
              "Para la extracción de tareas pendientes y",
              style: CTextStyle.bodyMedium,
            ),
            Text(
              "materias, es necesaria su autorización",
              style: CTextStyle.bodyMedium,
            ),

            SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdigris,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.lapizlazuli,
                              ),
                              SizedBox(width: 20),
                              Center(child: Text('Sincronizando...', style: CTextStyle.bodyMediuimbold,)),
                            ],
                          ),
                          SizedBox(height: 10,),
                          Center(child: Text('Esto puede tardar unos minutos', style: CTextStyle.bodySmall,))
                        ],
                      ),
                    );
                  },
                );

                try {
                  googleUser = await authService.value.linkGoogleAccount();

                  // Cerrar el diálogo
                  Navigator.of(context).pop();

                  // Mostrar mensaje de éxito
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor:  googleUser != null ? AppColors.lapizlazuli : Colors.red,
                      content: googleUser != null ? Text('¡Sincronización completada!') : Text('Error al sincronizar'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  // Cerrar el diálogo en caso de error
                  Navigator.of(context).pop();

                  // Mostrar mensaje de error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(
                  'SOLICITAR ACCESO A CLASSROOM',
                  style: CTextStyle.bodyMediuimbold.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            SizedBox(height: 8),
            Text(
              'Solo se sincronizaran asiganaciones de Classroom',
              style: CTextStyle.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
