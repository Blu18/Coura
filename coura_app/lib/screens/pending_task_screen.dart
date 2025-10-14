import 'package:cloud_firestore/cloud_firestore.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Mis Tareas Pendientes",
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('tareas')
            .orderBy(
              'fechaLimite',
              descending: false,
            ) // Opcional: ordenar tareas
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tienes tareas pendientes."));
          }

          // Procesas y agrupas las tareas
          var tareasAgrupadas = _agruparTareasPorMateria(snapshot.data!.docs);
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
      ), // Este será el widget principal del cuerpo
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tareas'),
          BottomNavigationBarItem(icon: Icon(Icons.data_usage), label: 'Datos'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Recordar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: 'Salir',
          ),
        ],
        // Estilos adicionales para que se vea como en la imagen
        type: BottomNavigationBarType.fixed, // Mantiene el layout fijo
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
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
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        leading: Icon(Icons.book_outlined, color: AppColors.verdigris),
        title: Row(
          children: [
            Expanded(
              child: Text(
                materia,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ).copyWith(color: AppColors.indigodye),
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
