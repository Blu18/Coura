import 'package:coura_app/screens/menu_screen.dart';
import 'package:coura_app/screens/register_screen.dart';
import 'package:coura_app/services/auth_service.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/app_images.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController correocontroller = TextEditingController();
  TextEditingController contracontroller = TextEditingController();
  bool _isChecked = false;
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
        rememberMe: _isChecked,
      );

      // Verificar que el widget esté montado antes de usar context
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MenuScreen()),
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

      if (!mounted) return;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Iniciar Sesión",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Image.asset(CAppImages.applogo, scale: 1.5)], 
            ),

            Text(
              "Accede a tu cuenta para sincronizar tus",
              style: CTextStyle.bodyMedium,
            ),
            Text("tareas y recordatorios", style: CTextStyle.bodyMedium),

            SizedBox(height: 60),
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

            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 25),
                Row(
                  children: [
                    CupertinoCheckbox(
                      value: _isChecked,
                      onChanged: (bool? value) {
                        setState(() {
                          _isChecked = value!;
                        });
                      },
                    ),

                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Text("Mantener sesión", style: CTextStyle.bodySmall),
                        Text("iniciada", style: CTextStyle.bodySmall),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 100),
                Column(
                  children: [
                    Text(
                      "¿Olvidaste tu",
                      style: CTextStyle.bodySmall.copyWith(
                        color: Colors.blueAccent,
                      ),
                    ),
                    Text(
                      " contraseña?",
                      style: CTextStyle.bodySmall.copyWith(
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 1),
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
                Text("¿No tienes cuenta?", style: CTextStyle.bodySmall),
                TextButton(
                  onPressed: () {
                    popPage();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterScreen()),
                    );
                  },
                  child: Text(
                    "Regístrate",
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
