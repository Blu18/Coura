import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/utils/custom/custom_dropdown_field.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/custom/custom_time_field.dart';
import 'package:coura_app/utils/custom/date_picker_form_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RegisterActivity extends StatefulWidget {
  const RegisterActivity({super.key});

  @override
  State<RegisterActivity> createState() => _RegisterActivityState();
}

class _RegisterActivityState extends State<RegisterActivity> {
  TextEditingController nombrecontroller = TextEditingController();
  TextEditingController descripcioncontroller = TextEditingController();
  TextEditingController materiacontroller = TextEditingController();
  TextEditingController fechacontroller = TextEditingController();
  TextEditingController horacontroller = TextEditingController();
  String? _selectedPrioridad;
  final List<String> prioridades = ['Alta', 'Media', 'Baja'];
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    nombrecontroller.dispose();
    descripcioncontroller.dispose();
    materiacontroller.dispose();
    fechacontroller.dispose();
    horacontroller.dispose();
    super.dispose();
  }

  Future<void> _guardarTarea() async {
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return; // Si no es válido, no hagas nada
    }

    // 2. Obtener el usuario actual
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Muestra un error si no hay un usuario logueado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Debes iniciar sesión para guardar una tarea.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final fechaStr = fechacontroller.text;
      final horaStr = horacontroller.text;
      final formato = DateFormat('dd/MM/yyyy h:mm a');
      final DateTime fechaLimite = formato.parse('$fechaStr $horaStr');

      // 4. Preparar los datos para Firestore
      final datosTarea = {
        'nombre': nombrecontroller.text,
        'descripcion': descripcioncontroller.text,
        'materia': materiacontroller.text,
        'prioridad': _selectedPrioridad,
        'fechaLimite': Timestamp.fromDate(
          fechaLimite,
        ), // Convertir a Timestamp de Firestore
        'creadoEn':
            FieldValue.serverTimestamp(), // Firestore pondrá la fecha de creación
        'completada': false, // Estado inicial de la tarea
      };

      // 5. Enviar los datos a la subcolección del usuario
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignments')
          .add(datosTarea);

      // 6. Mostrar mensaje de éxito y navegar hacia atrás
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Tarea guardada con éxito!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      // Manejo de errores
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrió un error al guardar: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      }); // Detiene el estado de carga
    }
  }

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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CustomField(
                      title: "Nombre / Titulo",
                      controller: nombrecontroller,
                      hintText: "Ej: Proyecto de Inglés - Presentación oral",
                      isthisRequired: true,
                    ),
                    CustomField(
                      title: "Descripción",
                      controller: descripcioncontroller,
                      hintText:
                          "Ej: Investigar y preparar diapositivas sobre calentamiento global",
                    ),
                    CustomField(
                      title: "Materia",
                      controller: materiacontroller,
                      hintText: "Ej: Inglés Técnico Avanzado",
                      isthisRequired: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DatePickerFormField(
                            title: "Fecha Límite",
                            controller: fechacontroller,
                            isThisRequired: true,
                          ),
                        ),

                        Expanded(
                          child: TimePickerFormField(
                            title: "Hora",
                            controller: horacontroller,
                            isThisRequired: true,
                          ),
                        ),
                      ],
                    ),
                    DropdownFormFieldCustom(
                      title: "Prioridad",
                      hintText: "Selecciona una opción",
                      items: prioridades,
                      isThisRequired: true,
                      value: _selectedPrioridad,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedPrioridad = newValue;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.verdigris,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: _isLoading ? null : _guardarTarea,
                        child: _isLoading
                            // Si está cargando, muestra un indicador circular
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            // Si no, muestra el texto y el icono
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    "GUARDAR TAREA PENDIENTE",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ), // Asegúrate de definir el estilo
                                  ),
                                ],
                              ),
                      ),
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
            ),
          ],
        ),
      ),
    );
  }
}
