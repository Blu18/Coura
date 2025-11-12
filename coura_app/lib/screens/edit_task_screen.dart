import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/utils/custom/custom_text_field.dart';
import 'package:coura_app/utils/custom/date_picker_form_field.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';
import 'package:coura_app/utils/custom/custom_dropdown_field.dart';
import 'package:coura_app/utils/custom/custom_time_field.dart';
import 'package:intl/intl.dart';

class EditTaskScreen extends StatefulWidget {
  // 1. We receive the entire task document
  final DocumentSnapshot tareaDocumento;

  const EditTaskScreen({super.key, required this.tareaDocumento});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nombreController;
  late TextEditingController descripcionController;
  late TextEditingController materiaController;
  late TextEditingController fechaController;
  late TextEditingController horaController;

  String? _selectedPrioridad;

  final List<String> prioridades = ['Alta', 'Media', 'Baja'];

  @override
  void initState() {
    super.initState();
    // 2. Extract the data from the document
    final datos = widget.tareaDocumento.data() as Map<String, dynamic>;

    // 3. Initialize the controllers with the existing data
    nombreController = TextEditingController(text: datos['nombre'] ?? '');
    descripcionController = TextEditingController(
      text: datos['descripcion'] ?? '',
    );
    materiaController = TextEditingController(text: datos['materia'] ?? '');
    _selectedPrioridad = datos['prioridad'] ?? 'Media';

    // Format date and time from the Timestamp
    if (datos['fechaLimite'] != null) {
      DateTime fechaLimite = (datos['fechaLimite'] as Timestamp).toDate();
      fechaController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(fechaLimite),
      );
      horaController = TextEditingController(
        text: DateFormat('h:mm a').format(fechaLimite),
      );
    } else {
      fechaController = TextEditingController();
      horaController = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Clean up the controllers
    nombreController.dispose();
    descripcionController.dispose();
    materiaController.dispose();
    fechaController.dispose();
    horaController.dispose();
    super.dispose();
  }

  Future<void> _actualizarTarea() async {
    if (!_formKey.currentState!.validate()) return;

    // Logic to update the task in Firestore
    try {
      final fechaStr = fechaController.text;
      final horaStr = horaController.text;
      final formato = DateFormat('dd/MM/yyyy h:mm a');
      final DateTime fechaLimite = formato.parse('$fechaStr $horaStr');

      await widget.tareaDocumento.reference.update({
        'nombre': nombreController.text,
        'descripcion': descripcionController.text,
        'materia': materiaController.text,
        'prioridad': _selectedPrioridad,
        'fechaLimite': Timestamp.fromDate(fechaLimite),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Tarea actualizada!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  Future<void> _marcarCompletado() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await widget.tareaDocumento.reference.update({'completada': true});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('¡Tarea Completada!')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errorr al completar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Editar Tarea",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Color(0xFFE91E63),
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.tareaDocumento['nombre'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 10,),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15.0),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 248, 248, 248),
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text("Estatus de la Tarea:", style: CTextStyle.bodyMediuimbold.copyWith(color: const Color.fromARGB(255, 90, 90, 90)),)
                      ],
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(widget.tareaDocumento['completada'] ? "Completada" : "Pendiente", 
                          style: CTextStyle.bodyMediuimbold.copyWith(color: widget.tareaDocumento['completada'] ? Colors.green : Colors.red),)
                        ],
                      ),
                    )
                  ],
                ),
              ),
              CustomField(
                title: "Nombre / Titulo",
                controller: nombreController,
                isthisRequired: true,
              ),
              CustomField(
                title: "Descripción",
                controller: descripcionController,
              ),
              CustomField(
                title: "Materia",
                controller: materiaController,
                isthisRequired: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: DatePickerFormField(
                      title: "Fecha Límite",
                      controller: fechaController,
                      isThisRequired: true,
                    ),
                  ),
                  Expanded(
                    child: TimePickerFormField(
                      title: "Hora",
                      controller: horaController,
                    ),
                  ),
                ],
              ),
              DropdownFormFieldCustom(
                title: "Prioridad",
                value: _selectedPrioridad,
                items: prioridades,
                isThisRequired: true,
                onChanged: (newValue) {
                  setState(() {
                    _selectedPrioridad = newValue;
                  });
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightgreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _marcarCompletado,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      "MARCAR COMO COMPLETADO ",
                      style: TextStyle(
                        color: Colors.white,
                      ), // Asegúrate de definir el estilo
                    ),
                  ],
                ),
              ),
              /*ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 80,
                            ),
                            SizedBox(height: 20),
                            Text(
                              "¿Estás seguro?",
                              style: CTextStyle.bodyLarge.copyWith(
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "¿Deseas eliminar permanentemente la tarea?",
                              style: CTextStyle.bodySmall,
                            ),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 36.3,
                                    ),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    side: BorderSide(
                                      color: const Color.fromARGB(
                                        255,
                                        56,
                                        56,
                                        56,
                                      ), // Color del borde
                                      width: 0.5, // Grosor del borde
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    "Cancelar",
                                    style: CTextStyle.bodyMediuimbold.copyWith(
                                      color: const Color.fromARGB(
                                        255,
                                        103,
                                        102,
                                        102,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 36.3,
                                    ),
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                    widget.tareaDocumento.reference.delete();
                                    Navigator.pop(context, true);
                                    
                                  },
                                  child: Text(
                                    "Eliminar",
                                    style: CTextStyle.bodyMediuimbold.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      "ELIMINAR TAREA",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),*/
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdigris,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _actualizarTarea,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      "ACTUALIZAR TAREA",
                      style: TextStyle(
                        color: Colors.white,
                      ), // Asegúrate de definir el estilo
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
