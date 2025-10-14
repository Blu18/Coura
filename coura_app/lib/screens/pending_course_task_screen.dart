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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              // 3. El truco principal: un padding superior que es MENOR a la altura
              //    del header para crear el efecto de superposición.
              padding: const EdgeInsets.only(
                top: 10.0,
                left: 20.0,
                right: 20.0,
              ),
              child: Container(
                width: double.infinity, // Ocupa todo el ancho posible
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: AppColors.lapizlazuli,
                  border: Border(
                    bottom: BorderSide(color: AppColors.keppel, width: 6),
                  ),
                  // 4. Bordes redondeados para la tarjeta
                  borderRadius: BorderRadius.circular(15.0),
                  // Sombra sutil para darle profundidad (opcional)
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // Contenido de la tarjeta
                child: Text(
                  widget.materia,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.3, // Espacio entre líneas
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(
                top: 10.0,
                left: 20.0,
                right: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10, width: double.infinity),
                  Text(
                    "Próximas entregas",
                    style: CTextStyle.headlineLarge.copyWith(
                      color: AppColors.lapizlazuli,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  ListView.builder(
                    itemCount: widget.tareas.length,
                    itemBuilder: (context, index) {
                      final tareaDocumento = widget.tareas[index];

                      // 2. Convierte los datos del documento a un Map.
                      final datosDeLaTarea =
                          tareaDocumento.data() as Map<String, dynamic>;

                      // 3. Pasa solo los datos de esa tarea al TareaCard.
                      return TareaCard(tarea: datosDeLaTarea);
                    },
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
                    fechaFormateada,
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
        ],
      ),
    );
  }
}
