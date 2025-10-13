import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class RegisterActivity extends StatefulWidget {
  const RegisterActivity({super.key});

  @override
  State<RegisterActivity> createState() => _RegisterActivityState();
}

class _RegisterActivityState extends State<RegisterActivity> {
  TextEditingController nombrecontroller = TextEditingController();
  TextEditingController descripcioncontroller = TextEditingController();
  TextEditingController materiacontroller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Registro Manual de Tarea",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.025),
            Text(
              "Registro de Tareas",
              style: CTextStyle.headlineLarge.copyWith(
                color: AppColors.cerulean,
              ),
            ),
            Text(
              "Agrega actividades académicas fuera de los tablones",
              style: CTextStyle.bodyMedium.copyWith(
                color: const Color.fromARGB(255, 80, 80, 80),
              ),
            ),
            Text(
              "oficiales",
              style: CTextStyle.bodyMedium.copyWith(
                color: const Color.fromARGB(255, 80, 80, 80),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomField(
                    title: "Nombre / Titulo",
                    controller: nombrecontroller,
                    hintText: "EJ: Proyecto de Inglés - Presentación oral",
                    isthisRequired: true,
                  ),
                  CustomField(
                    title: "Descripción",
                    controller: descripcioncontroller,
                    hintText: "Investigar y preparar diapositivas sobre calentamiento global",
                  ),
                  CustomField(
                    title: "Materia",
                    controller: materiacontroller,
                    hintText: "Ej: Inglés Técnico Avanzado",
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

class CustomTextField {}
