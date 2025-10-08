import 'package:coura_app/screens/login_screen.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/app_images.dart';
import 'package:coura_app/utils/styles/text_style.dart';
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
                  CustomField(
                    title: "Nombre Completo",
                    controller: nombrecontroller,
                    hintText: "Ej: Juan Pérez",
                  ),
                  CustomField(
                    title: "Correo Electrónico",
                    controller: correocontroller,
                    hintText: "Ej: tu-correo@dominio.com",
                  ),
                  CustomField(
                    title: "Contraseña",
                    controller: contracontroller,
                    hintText: "Mínimo 6 caracteres",
                    isThisPassword: true,
                  ),
        
                  SizedBox(height: 2),
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.lapizlazuli,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Center(
                      child: Text(
                        "REGISTRARME",
                        style: CTextStyle.titleMediumbold.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
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
                      Text("¿Ya tienes una cuenta?", style: CTextStyle.bodySmall),
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
