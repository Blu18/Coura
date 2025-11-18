import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/screens/pending_course_task_screen.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingTaskScreen extends StatefulWidget {
  const PendingTaskScreen({super.key});

  @override
  State<PendingTaskScreen> createState() => _PendingTaskScreen();
}

class _PendingTaskScreen extends State<PendingTaskScreen> {
  Map<String, List<DocumentSnapshot>> _agruparTareasPorMateria(
    List<DocumentSnapshot> docs,
  ) {
    Map<String, List<DocumentSnapshot>> mapa = {};
    for (var doc in docs) {
      String materia = doc['materia'];
      if (mapa[materia] == null) {
        mapa[materia] = [];
      }
      mapa[materia]!.add(doc);
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now().toUtc();
    final dosMesesAtras = DateTime.utc(ahora.year, ahora.month - 3, ahora.day);

    final formato = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final fechaLimiteStr = formato.format(dosMesesAtras);

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('assignments')
            .where('completada', isEqualTo: false)
            .orderBy('fechaLimite', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No tienes tareas pendientes."));
          }

          // Filtrar documentos en el cliente
          var documentosFiltrados = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final classroomData =
                data['_classroom_data'] as Map<String, dynamic>?;

            // Si no tiene classroomId, incluirlo (tarea creada manualmente)
            if (data['classroomId'] == null) return true;

            // Si tiene _classroom_data, verificar las fechas
            if (classroomData != null) {
              final creationTime = classroomData['creationTime'] as String?;
              final updateTime = classroomData['updateTime'] as String?;

              return (creationTime != null &&
                      creationTime.compareTo(fechaLimiteStr) >= 0) ||
                  (updateTime != null &&
                      updateTime.compareTo(fechaLimiteStr) >= 0);
            }

            // Si tiene classroomId pero no tiene _classroom_data, no incluirlo
            return false;
          }).toList();

          // Verificar si hay documentos después del filtrado
          if (documentosFiltrados.isEmpty) {
            return const Center(child: Text("No tienes tareas pendientes."));
          }

          // Procesas y agrupas las tareas
          var tareasAgrupadas = _agruparTareasPorMateria(documentosFiltrados);
          var materias = tareasAgrupadas.keys.toList();

          // Y aquí retornas el ListView que construye la interfaz
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: materias.length,
            itemBuilder: (context, index) {
              String materia = materias[index];
              List<DocumentSnapshot> tareasDeLaMateria =
                  tareasAgrupadas[materia]!;
              return ExpansionTileMateria(
                materia: materia,
                tareas: tareasDeLaMateria,
              );
            },
          );
        },
      ),
    );
  }
}

// Widget para la tarjeta de materia expandible
class ExpansionTileMateria extends StatelessWidget {
  final String materia;
  final List<DocumentSnapshot> tareas;

  const ExpansionTileMateria({
    super.key,
    required this.materia,
    required this.tareas,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(255, 248, 248, 248),
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        leading: Icon(Icons.book_outlined, color: AppColors.verdigris),
        title: Row(
          children: [
            Expanded(
              child: TextButton(
                child: Text(
                  materia,
                  style: CTextStyle.bodyMediuimbold.copyWith(
                    color: AppColors.indigodye,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PendingCourseTaskScreen(
                        tareas: tareas,
                        materia: materia,
                      ),
                    ),
                  );
                },
              ),
            ),
            Chip(
              label: Text('${tareas.length} Pendiente'),
              backgroundColor: AppColors.lapizlazuli,
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
        children: tareas.map((tareaDoc) {
          return TareaCard(tarea: tareaDoc.data() as Map<String, dynamic>);
        }).toList(),
      ),
    );
  }
}

// Widget para la tarjeta de tarea individual
class TareaCard extends StatelessWidget {
  final Map<String, dynamic> tarea;

  const TareaCard({super.key, required this.tarea});

  String? getEstadoFecha(int diasRestantes) {
    if (diasRestantes < 0) return "Vencida";
    if (diasRestantes < 3) return "Por vencer";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rawFecha = tarea['fechaLimite'];
    DateTime? fechaLimite;

    // Primero convertir la fecha
    if (rawFecha != null) {
      fechaLimite = (rawFecha as Timestamp).toDate();
    }

    // Luego calcular días restantes y estado
    int? diasRestantes;
    String? estado;

    if (fechaLimite != null) {
      diasRestantes = fechaLimite.difference(DateTime.now()).inDays;
      estado = getEstadoFecha(diasRestantes);
    }

    // Formatear la fecha
    String fechaFormateada = fechaLimite != null
        ? DateFormat('dd/MM/yyyy - HH:mm').format(fechaLimite)
        : 'Sin fecha';

    // Determinar color de prioridad
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
                labelStyle: const TextStyle(
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
          if (estado != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: estado == "Vencida"
                    ? Colors.red.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                estado,
                style: TextStyle(
                  color: estado == "Vencida" ? Colors.red : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
