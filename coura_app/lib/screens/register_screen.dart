import 'package:coura_app/screens/home_screen.dart';
import 'package:coura_app/screens/login_screen.dart';
import 'package:coura_app/utils/custom/custom_name_field.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/app_images.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  TextEditingController nombrecontroller = TextEditingController();
  TextEditingController correocontroller = TextEditingController();
  TextEditingController contracontroller = TextEditingController();
  // final _formKey = GlobalKey<FormState>();
  String errorMessage = '';

  @override
  void dispose() {
    nombrecontroller.dispose();
    correocontroller.dispose();
    contracontroller.dispose();
    super.dispose();
  }

  void register() async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: correocontroller.text,
        password: contracontroller.text,
      );
      User? user = userCredential.user;

      if (user != null) {
        await user.updateProfile(displayName: nombrecontroller.text.trim());
        await user.reload();
        print(
          "¡Cuenta creada y nombre guardado exitosamente: ${user.displayName}!",
        );
      }
      popPage();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String translatedError = "Ocurrio un error";
      switch (e.code) {
        case 'weak-password':
          translatedError = "La contraseña debe tener al menos 6 caracteres.";
          break;
        case 'email-already-in-use':
          translatedError =
              "Este correo electrónico ya está en uso por otra cuenta.";
          break;
        case 'invalid-email':
          translatedError = "Correo electrónico invalido.";
          break;
        case 'operation-not-allowed':
          translatedError =
              "La creación de cuentas con correo y contraseña no está habilitada.";
          break;
        case 'network-request-failed':
          translatedError = "Error de red. Revisa tu conexión a internet.";
          break;
        default:
          translatedError =
              "No se pudo registrar el usuario. Por favor, intenta de nuevo.";
          print(
            'Error no manejado: ${e.code}',
          ); // Imprime el código para depuración
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
      appBar: AppBar(
        title: Text(
          "Registro de Cuenta",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: size.height * 0.125,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Image.asset(CAppImages.applogo, scale: 1.8)],
              ),
            ),
            Text(
              "Crea tu cuenta para acceder a tus tareas y",
              style: CTextStyle.bodyMediuimbold.copyWith(
                color: const Color.fromARGB(255, 80, 80, 80),
              ),
            ),
            Text(
              "recordatorios",
              style: CTextStyle.bodyMediuimbold.copyWith(
                color: const Color.fromARGB(255, 80, 80, 80),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  CustomNameField(
                    title: "Nombre Completo",
                    controller: nombrecontroller,
                    hintText: "Ej: Juan Pérez",
                  ),
                  CustomField(
                    title: "Correo Electrónico",
                    controller: correocontroller,
                    hintText: "Ej: tu-correo@dominio.com",
                    isThisPassword: false,
                    isthisRequired: true,
                  ),
                  CustomField(
                    title: "Contraseña",
                    controller: contracontroller,
                    hintText: "Mínimo 6 caracteres",
                    isThisPassword: true,
                    isthisRequired: true,
                  ),
                  Text(
                    errorMessage,
                    style: CTextStyle.bodyMedium.copyWith(color: Colors.red),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lapizlazuli,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                register();
              },
              child: Text(
                "REGISTRARME",
                style: CTextStyle.titleMediumbold.copyWith(color: Colors.white),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                spacing: 10,
                children: [
                  Row(
                    spacing: 7.5,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "¿Ya tienes una cuenta?",
                        style: CTextStyle.bodySmall,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Iniciar Sesión",
                          style: CTextStyle.bodySmall.copyWith(
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Monitoreo y Productividad",
                        style: CTextStyle.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
