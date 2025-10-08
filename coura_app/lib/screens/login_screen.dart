import 'package:coura_app/screens/register_screen.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/app_images.dart';
import 'package:coura_app/utils/styles/curvedclipper.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController correocontroller = TextEditingController();
  TextEditingController contracontroller = TextEditingController();

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
            Container(
              height: 45,
              width: size.width * 0.5,
              decoration: BoxDecoration(
                color: AppColors.lapizlazuli,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  "Iniciar Sesión",
                  style: CTextStyle.titleMediumbold.copyWith(color: Colors.white),
                ),
              ),
            ),
        
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Registrate", style: CTextStyle.bodySmall),
                TextButton(
                  onPressed: () {
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
