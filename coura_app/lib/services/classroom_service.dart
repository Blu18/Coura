import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coura_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/classroom/v1.dart' as classroom;

ValueNotifier<ClassroomService> classroomService = ValueNotifier(
  ClassroomService(),
);

class ClassroomService {
  final AuthService _authService = AuthService();

  Future<void> syncTasks() async {
    print("Usuario actual de Firebase: ${FirebaseAuth.instance.currentUser}");
    final googleAccount = await _authService.linkGoogleAccount();

    if (googleAccount == null) {
      print("La vinculación/inicio de sesión falló. No se puede sincronizar.");
      return;
    }

    print("Vinculación exitosa. Buscando tareas...");
    final classroomApi = await _authService.getClassroomApi();

    if (classroomApi == null) {
      return;
    }

    await fetchAndSyncAssignments(classroomApi);
  }

  Future<void> fetchAndSyncAssignments(
    classroom.ClassroomApi classroomApi,
  ) async {
    debugPrint("Intentando obtener cliente API de classroom...");

    try {
      // Obtener los cursos del usuario
      final response = await classroomApi.courses.list(studentId: 'me');
      final courses = response.courses;

      if (courses == null || courses.isEmpty) {
        debugPrint("El usuario no tiene cursos.");
        return;
      }

      debugPrint(
        "Se encontraron ${courses.length} cursos. Extrayendo trabajos...",
      );

      // Recorremos cada curso
      for (final course in courses) {
        if (course.courseState == 'ACTIVE') {
          final courseworkResponse = await classroomApi.courses.courseWork.list(
            course.id!,
          );
          final assignments = courseworkResponse.courseWork;

          if (assignments == null || assignments.isEmpty) continue;

          // Recorremos cada tarea para obtener sus entregas
          for (final work in assignments) {
            final submissionsResponse = await classroomApi
                .courses
                .courseWork
                .studentSubmissions
                .list(course.id!, work.id!, userId: 'me');

            final submissions = submissionsResponse.studentSubmissions ?? [];
            final submission = submissions.isNotEmpty
                ? submissions.first
                : null;

            // Guardamos la tarea y su estado
            await _saveAssignmentToFirestore(
              work,
              course.name ?? 'Sin nombre',
              submission,
            );

            // Mensaje de depuración
            // final state = submission?.state ?? 'SIN ENVÍO';
            // debugPrint("→ ${work.title} (${state}) guardada en Firestore");
          }
        }
      }
    } catch (e) {
      debugPrint("Ocurrió un error al extraer datos de Classroom: $e");
    }
  }

  Future<void> _saveAssignmentToFirestore(
    classroom.CourseWork assignment,
    String courseName,
    classroom.StudentSubmission? submission,
  ) async {
    // Obtener el usuario actual
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Salir si no hay usuario

    final tareasRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('assignments');

    // Lógica para evitar duplicados
    // Buscamos si ya existe una tarea con el ID único de Classroom.
    final query = await tareasRef
        .where('classroomId', isEqualTo: assignment.id)
        .limit(1)
        .get();

    // Si la consulta devuelve algún documento, la tarea ya existe. No hacemos nada.
    if (query.docs.isNotEmpty) {
      return;
    }

    // Mapear los datos de Classroom a estructura de Firestore
    DateTime? fechaLimite;
    if (assignment.dueDate != null) {
      // Combinamos la fecha y la hora de Classroom en un solo objeto DateTime
      final date = assignment.dueDate!;
      final time = assignment.dueTime;
      fechaLimite = DateTime(
        date.year ?? DateTime.now().year,
        date.month ?? DateTime.now().month,
        date.day ?? DateTime.now().day,
        time?.hours ?? 23, // Si no hay hora, por defecto al final del día
        time?.minutes ?? 59,
      );
    }

    bool estaCompletada = false; // Por defecto es 'no completada'
    if (submission != null) {
      // 'TURNED_IN' = El alumno la entregó
      // 'RETURNED' = El profesor la calificó y devolvió
      // Ambos estados significan que la tarea está "completada"
      if (submission.state == 'TURNED_IN' || submission.state == 'RETURNED') {
        estaCompletada = true;
      }
    }

    final datosTarea = {
      // Campos que sí podemos mapear directamente
      'nombre': assignment.title ?? 'Tarea sin título',
      'descripcion': assignment.description ?? 'Sin descripción.',
      'materia': courseName,
      'fechaLimite': fechaLimite != null
          ? Timestamp.fromDate(fechaLimite)
          : null,

      // Campos con valores por defecto
      'completada':
          estaCompletada, // Las tareas importadas siempre están pendientes
      'prioridad':
          'Media', // Classroom no tiene prioridad, asignamos una por defecto
      'creadoEn': FieldValue.serverTimestamp(),

      // Campo especial para evitar duplicados y para futuras referencias
      'classroomId': assignment.id,
      'classroomLink': assignment
          .alternateLink, // Muy útil para que el usuario pueda ir a la tarea
    };

    // Añadir la nueva tarea a Firestore
    await tareasRef.add(datosTarea);
  }
}
