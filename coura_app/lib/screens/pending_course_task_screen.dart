import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/screens/edit_task_screen.dart';
import 'package:coura_app/utils/custom/buttons/classroom_button.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingCourseTaskScreen extends StatefulWidget {
  final List<DocumentSnapshot> tareas;
  final String materia;

  const PendingCourseTaskScreen({
    super.key,
    required this.tareas,
    required this.materia,
  });

  @override
  State<PendingCourseTaskScreen> createState() => _PendingCourseTaskScreen();
}

class _PendingCourseTaskScreen extends State<PendingCourseTaskScreen> {
  late List<DocumentSnapshot> _tareasLocales;

  @override
  void initState() {
    super.initState();
    _tareasLocales = widget.tareas;
  }

  void _recargarTareas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('assignments')
        .where('completada', isEqualTo: false)
        .where('materia', isEqualTo: widget.materia)
        .orderBy(
          'fechaLimite',
          descending: false,
        ) // Re-ejecuta la misma consulta original
        .get();

    setState(() {
      _tareasLocales = snapshot.docs;
      if(_tareasLocales.isEmpty) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 248, 248),
      appBar: AppBar(
        title: Text(
          "Tareas Pendientes",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.lapizlazuli,
                border: Border(
                  bottom: BorderSide(color: AppColors.keppel, width: 6),
                ),
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
                widget.materia,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Text(
              "Próximas entregas",
              style: CTextStyle.headlineLarge.copyWith(
                color: AppColors.lapizlazuli,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _tareasLocales.length,
              itemBuilder: (context, index) {
                final tareaDocumento = _tareasLocales[index];
                return TareaCard(
                  tareaDocumento: tareaDocumento,
                  onEditSucces: _recargarTareas,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TareaCard extends StatelessWidget {
  final DocumentSnapshot tareaDocumento;
  final VoidCallback onEditSucces;

  const TareaCard({
    super.key,
    required this.tareaDocumento,
    required this.onEditSucces,
  });

  @override
  Widget build(BuildContext context) {
    var tarea = tareaDocumento.data() as Map<String, dynamic>;
    final rawFecha = tarea['fechaLimite'];
    DateTime? fechaLimite;

    if (rawFecha != null) {
      fechaLimite = (rawFecha as Timestamp).toDate();
    }

    // 1. Declara la variable de texto
    String fechaFormateada;

    // 2. Comprueba si 'fechaLimite' es nulo ANTES de llamar a .format()
    if (fechaLimite != null) {
      // Si NO es nulo, formatea la fecha
      fechaFormateada = DateFormat('dd/MM/yyyy - HH:mm').format(fechaLimite);
    } else {
      // Si ES nulo, asigna un texto por defecto
      fechaFormateada = "Sin fecha límite";
    }

    Color pColor;
    if (tarea['prioridad'] == 'Alta') {
      pColor = AppColors.indigodye;
    } else if (tarea['prioridad'] == 'Media') {
      pColor = AppColors.cerulean;
    } else {
      pColor = AppColors.lightergreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: pColor, width: 4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tarea['nombre'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              tarea['sincronizado_desde_classroom'] != null? ClassroomButton(
                              bgColor: Colors.blue,
                              iconColor: Colors.white,
                              url:
                                  tarea['classroomLink'] ??
                                  "https://classroom.google.com/",
                            ) : const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.bondiblue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Entrega: ${fechaFormateada}",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              Chip(
                label: Text(tarea['prioridad']),
                backgroundColor: pColor,
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          Text(tarea['descripcion'] ?? "", style: CTextStyle.bodySmall),
          tarea['classroomId'] == null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditTaskScreen(tareaDocumento: tareaDocumento),
                          ),
                        );

                        if (result == true) {
                          onEditSucces();
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: AppColors.lapizlazuli,
                          ),
                          SizedBox(width: 5),
                          Text(
                            "Editar",
                            style: CTextStyle.bodySmall.copyWith(
                              color: AppColors.lapizlazuli,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : SizedBox(height: 10,),
        ],
      ),
    );
  }
}
