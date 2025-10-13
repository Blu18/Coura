import 'package:coura_app/screens/home_screen.dart';
import 'package:coura_app/screens/register_screen.dart';
import 'package:coura_app/services/auth_service.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/app_images.dart';
import 'package:coura_app/utils/styles/curvedclipper.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController correocontroller = TextEditingController();
  TextEditingController contracontroller = TextEditingController();
  String errorMessage = '';

  @override
  void dispose() {
    correocontroller.dispose();
    contracontroller.dispose();
    super.dispose();
  }

  void signIn() async {
    try {
      await authService.value.signIn(
        email: correocontroller.text,
        password: contracontroller.text,
      );
      popPage();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String translatedError = "Ocurrio un error";
      switch (e.code) {
        case 'user-not-found':
          translatedError = "Usuario no encontrado";
          break;
        case 'wrong-password':
          translatedError = "La contraseña es incorrecta";
          break;
        case 'invalid-email':
          translatedError = "Correo electrónico no es válido.";
          break;
        case 'user-disabled':
          translatedError = "Este usuario ha sido deshabilitado.";
          break;
        case 'too-many-requests':
          translatedError =
              "Se han bloqueado las solicitudes por actividad inusual. Intenta más tarde.";
          break;
        case 'network-request-failed':
          translatedError = "Error de red. Revisa tu conexión a internet.";
          break;
        default:
          translatedError =
              "Error al iniciar sesión. Verifica tus credenciales.";
          print('Error no manejado: ${e.code}');
      }

      setState(() {
        errorMessage = translatedError;
      });
    }
  }

  void popPage() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          spacing: 22.5,
          children: [
            ClipPath(
              clipper: CurvedClipper(),
              child: Container(
                color: AppColors.lapizlazuli,
                height: size.height * 0.25,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Image.asset(CAppImages.applogo, scale: 1.5)],
                ),
              ),
            ),
            Text("¡Bienvenido!", style: CTextStyle.tittleLarge),
            CustomField(
              title: "Correo Electrónico",
              controller: correocontroller,
              hintText: "tu-correo@dominio.com",
            ),
            CustomField(
              title: "Contraseña",
              controller: contracontroller,
              hintText: "Minimo 6 caracteres",
              isThisPassword: true,
            ),

            SizedBox(height: 1),
            Text(
              errorMessage,
              style: CTextStyle.bodyMedium.copyWith(color: Colors.red),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lapizlazuli,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                signIn();
              },
              child: Text(
                "Iniciar Sesión",
                style: CTextStyle.titleMediumbold.copyWith(color: Colors.white),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Registrate", style: CTextStyle.bodySmall),
                TextButton(
                  onPressed: () {
                    popPage();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterScreen()),
                    );
                  },
                  child: Text(
                    "aquí",
                    style: CTextStyle.bodySmall.copyWith(
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
