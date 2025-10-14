import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Tareas Pendientes",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
      ),
      body: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Alinea los hijos a la izquierda
        children: [
          // 1. El header con el nombre de la materia
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              0,
            ), // Ajusta el padding
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

          // 2. El título "Próximas entregas"
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Text(
              "Próximas entregas",
              style: CTextStyle.headlineLarge.copyWith(
                color: AppColors.lapizlazuli,
              ),
            ),
          ),

          // 3. LA LISTA DE TAREAS QUE OCUPA EL RESTO DEL ESPACIO
          // Expanded funciona correctamente ahora porque la Column tiene un tamaño definido.
          Expanded(
            child: ListView.builder(
              // Añade un poco de padding para que las tarjetas no peguen a los bordes
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: widget.tareas.length,
              itemBuilder: (context, index) {
                final tareaDocumento = widget.tareas[index];
                final datosDeLaTarea =
                    tareaDocumento.data() as Map<String, dynamic>;
                return TareaCard(tarea: datosDeLaTarea);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TareaCard extends StatelessWidget {
  final Map<String, dynamic> tarea;

  const TareaCard({super.key, required this.tarea});

  @override
  Widget build(BuildContext context) {
    DateTime fechaLimite = (tarea['fechaLimite'] as Timestamp).toDate();
    String fechaFormateada = DateFormat(
      'dd/MM/yyyy - HH:mm',
    ).format(fechaLimite);

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
          Text(
            tarea['nombre'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  borderRadius: BorderRadius.circular(
                    20,
                  ), // Un valor alto para que sea ovalado
                ),
              ),
            ],
          ),
          Text(tarea['descripcion'], style: CTextStyle.bodySmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {},
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppColors.lapizlazuli),
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
          ),
        ],
      ),
    );
  }
}
