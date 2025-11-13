import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/classroom/v1.dart' as classroom;
import 'dart:convert';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  final String PUB_SUB_TOPIC_NAME =
      "projects/coura-3ab8e/topics/classroom-events";

  static const String clientID =
      "364990375311-hmkt7m7412rk0nujgjchhn8q33mmsh49.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: clientID,
    forceCodeForRefreshToken: true,
    scopes: [
      'email',
      classroom.ClassroomApi.classroomCoursesReadonlyScope,
      classroom.ClassroomApi.classroomCourseworkMeReadonlyScope,
      classroom.ClassroomApi.classroomPushNotificationsScope,
    ],
  );

  Future<UserCredential> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    UserCredential userCredential = await firebaseAuth
        .signInWithEmailAndPassword(email: email, password: password);

    // Guardar preferencia en Firestore
    if (userCredential.user != null) {
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'rememberMe': rememberMe,
      }, SetOptions(merge: true));
    }

    return userCredential;
  }

  Future<bool> shouldKeepSession() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['rememberMe'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    final user = firebaseAuth.currentUser;
    await firebaseAuth.signOut();

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'rememberMe': false,
      }, SetOptions(merge: true));
    }

    await firebaseAuth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUsername({required String username}) async {
    await currentUser!.updateDisplayName(username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  Future<classroom.ClassroomApi?> getClassroomApi() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently();

      if (googleUser == null) {
        debugPrint(
          "El usuario no ha iniciado sesión con Google o revocó los permisos.",
        );
        return null;
      }

      final http.Client? client = await _googleSignIn.authenticatedClient();

      if (client == null) {
        debugPrint("Error: No se pudo crear el cliente autenticado.");
        return null;
      }

      return classroom.ClassroomApi(client);
    } catch (e) {
      debugPrint("Error al obtener el cliente de Classroom API: $e");
      return null;
    }
  }

  Future<GoogleSignInAccount?> linkGoogleAccount() async {
    GoogleSignInAccount? googleUser;
    GoogleSignInAuthentication? googleAuth;

    try {
      await _googleSignIn.signOut();
      googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("El usuario canceló el inicio de sesión con Google.");
        return null;
      }

      googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        debugPrint("¡Cuenta de Firebase vinculada con Google exitosamente!");

        await _handlePostLinkActions(googleUser, googleAuth);

        return googleUser;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        debugPrint(
          "Esta cuenta de Google ya está vinculada (lo cual es correcto).",
        );

        if (googleUser != null && googleAuth != null) {
          debugPrint(
            "Procediendo a registrar notificaciones para la cuenta ya vinculada...",
          );
          await _handlePostLinkActions(googleUser, googleAuth);
          return googleUser;
        } else {
          debugPrint(
            "Error: No se pudo obtener googleUser o googleAuth en el catch.",
          );
          return null;
        }
      }

      debugPrint("Error de Firebase al vincular: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("Ocurrió un error inesperado al vincular: $e");
      return null;
    }
  }

  Future<void> _handlePostLinkActions(
    GoogleSignInAccount googleUser,
    GoogleSignInAuthentication googleAuth,
  ) async {
    try {
      final String? authCode = googleUser.serverAuthCode;
      if (authCode == null) {
        debugPrint(
          "Error: No se recibió serverAuthCode. Verifica tu serverClientId.",
        );
        return;
      }

      // Necesitamos el Firebase ID token
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Error: No hay usuario de Firebase logueado.");
        return;
      }
      final String? firebaseIdToken = await user.getIdToken();
      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      // 7. Envía los códigos a tu Cloud Function HTTP
      final response = await http.post(
        Uri.parse("https://exchange-authcode-364990375311.us-west2.run.app"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseIdToken',
        },
        body: jsonEncode({'authCode': authCode, 'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint("¡Éxito! Refresh token guardado en el backend.");
        await syncClassroomData();
      } else {
        debugPrint("Error al guardar token: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error en _handlePostLinkActions: $e");
    }
  }

  Future<void> syncClassroomData() async {
    debugPrint("Iniciando sincronización de Classroom...");
    final db = FirebaseFirestore.instance;

    final api = await getClassroomApi();
    if (api == null) {
      debugPrint("Error: No se pudo obtener la API de Classroom.");
      return;
    }

    final user = firebaseAuth.currentUser;
    if (user == null) {
      debugPrint("Error: No hay usuario logueado.");
      return;
    }

    try {
      // Obtener solo cursos ACTIVOS (igual que Python)
      final courseListResponse = await api.courses.list(
        studentId: "me",
        courseStates: ["ACTIVE"], // Solo cursos activos
      );
      final courses = courseListResponse.courses;

      if (courses == null || courses.isEmpty) {
        debugPrint("No se encontraron cursos activos.");
        return;
      }

      debugPrint("Encontrados ${courses.length} cursos activos");

      final batch = db.batch();
      final activeCourseIds = <String>[];

      for (var course in courses) {
        final courseId = course.id!;
        final courseName = course.name ?? 'Curso Sin Nombre';
        activeCourseIds.add(courseId);

        debugPrint("Obteniendo tareas para el curso: $courseName");

        try {
          final courseworkResponse = await api.courses.courseWork.list(
            courseId,
            courseWorkStates: ["PUBLISHED"],
            orderBy: "updateTime desc",
            pageSize: 10, // Las 10 más recientes
          );
          final assignments = courseworkResponse.courseWork;

          if (assignments != null && assignments.isNotEmpty) {
            debugPrint("   📝 $courseName: ${assignments.length} tareas");

            for (var assignment in assignments) {
              final assignmentId = assignment.id!;
              final title = assignment.title ?? 'Sin título';

              // Obtener estado de entrega (submission_state)
              String submissionState = 'NEW';
              try {
                final submissionResponse = await api
                    .courses
                    .courseWork
                    .studentSubmissions
                    .list(courseId, assignmentId, userId: 'me');

                final studentSubmissions =
                    submissionResponse.studentSubmissions;
                if (studentSubmissions != null &&
                    studentSubmissions.isNotEmpty) {
                  submissionState = studentSubmissions[0].state ?? 'NEW';
                }
              } catch (e) {
                debugPrint("Error verificando submission: $e");
              }

              // Referencia al documento
              final docRef = db
                  .collection('users')
                  .doc(user.uid)
                  .collection('assignments')
                  .doc(assignmentId);

              final docSnapshot = await docRef.get();

              // Convertir a tu formato (igual que Python)
              final taskData = _convertToAppFormat(
                assignment,
                courseName,
                courseId,
                submissionState,
              );

              if (docSnapshot.exists) {
                // Tarea ya existe - verificar cambios
                final existingData = docSnapshot.data()!;
                final oldCompletada = existingData['completada'] ?? false;
                final newCompletada = taskData['completada'];

                if (!oldCompletada && newCompletada) {
                  debugPrint("$title - Marcada como completada");
                  batch.update(docRef, {
                    'completada': true,
                    'submission_state': submissionState,
                    'ultima_actualizacion': FieldValue.serverTimestamp(),
                  });
                } else if (oldCompletada && !newCompletada) {
                  debugPrint("$title - Reabierta (estaba completada)");
                  batch.set(docRef, taskData);
                } else {
                  debugPrint("$title - Sin cambios");
                }
              } else {
                // Tarea NUEVA
                if (['TURNED_IN', 'RETURNED'].contains(submissionState)) {
                  debugPrint("$title - Ya entregada, solo guardando");
                } else {
                  debugPrint("NUEVA (Pendiente): $title");
                }
                batch.set(docRef, taskData);
              }
            }
          }
        } catch (e) {
          debugPrint("Error en curso $courseName: $e");
          continue;
        }
      }

      // Guardar cambios
      await batch.commit();
      debugPrint("Sincronización completada");

      // Marcar tareas de cursos archivados
      await _markArchivedCourseTasks(user.uid, activeCourseIds);
    } catch (e) {
      debugPrint("Error durante la sincronización: $e");
    }
  }

  Map<String, dynamic> _convertToAppFormat(
    classroom.CourseWork assignment,
    String courseName,
    String courseId,
    String submissionState,
  ) {
    // Extraer fecha límite
    Timestamp? fechaLimite;
    if (assignment.dueDate != null) {
      final dueDate = assignment.dueDate!;
      final dueTime = assignment.dueTime;

      final dateTime = DateTime(
        dueDate.year ?? DateTime.now().year,
        dueDate.month ?? 1,
        dueDate.day ?? 1,
        dueTime?.hours ?? 23,
        dueTime?.minutes ?? 59,
      );

      fechaLimite = Timestamp.fromDate(dateTime);
    }

    // Determinar prioridad basada en fecha límite
    String prioridad = "Media";
    if (fechaLimite != null) {
      final diasRestantes = fechaLimite
          .toDate()
          .difference(DateTime.now())
          .inDays;
      if (diasRestantes <= 2) {
        prioridad = "Alta";
      } else if (diasRestantes <= 7) {
        prioridad = "Media";
      } else {
        prioridad = "Baja";
      }
    }

    // Formato EXACTO del script de Python
    return {
      // Datos originales de Classroom
      '_classroom_data': {
        'creationTime': assignment.creationTime,
        'updateTime': assignment.updateTime,
        'maxPoints': assignment.maxPoints,
        'workType': assignment.workType,
        'state': assignment.state,
      },

      // Campos de la app
      'classroomId': assignment.id,
      'classroomLink': assignment.alternateLink ?? '',
      'completada': ['TURNED_IN', 'RETURNED'].contains(submissionState),
      'courseId': courseId,
      'creadoEn': FieldValue.serverTimestamp(),
      'curso_archivado': false,
      'descripcion': assignment.description ?? '',
      'fechaLimite': fechaLimite,
      'materia': courseName,
      'nombre': assignment.title ?? 'Sin título',
      'prioridad': prioridad,
      'sincronizado_desde_classroom': true,
      'submission_state': submissionState,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _markArchivedCourseTasks(
    String userId,
    List<String> activeCourseIds,
  ) async {
    try {
      debugPrint("Verificando tareas de cursos archivados...");

      final db = FirebaseFirestore.instance;

      final allTasks = await db
          .collection('users')
          .doc(userId)
          .collection('assignments')
          .where('sincronizado_desde_classroom', isEqualTo: true)
          .get();

      final batch = db.batch();
      int archivedCount = 0;

      for (var taskDoc in allTasks.docs) {
        final taskData = taskDoc.data();
        final courseId = taskData['courseId'] as String?;

        // Si la tarea tiene un courseId que NO está en la lista de activos
        if (courseId != null && !activeCourseIds.contains(courseId)) {
          final cursoArchivado = taskData['curso_archivado'] ?? false;

          if (!cursoArchivado) {
            debugPrint(
              "Archivando tarea: ${taskData['nombre'] ?? 'Sin título'}",
            );

            batch.update(taskDoc.reference, {
              'curso_archivado': true,
              'fecha_archivado': FieldValue.serverTimestamp(),
            });
            archivedCount++;
          }
        }
      }

      if (archivedCount > 0) {
        await batch.commit();
        debugPrint("$archivedCount tareas marcadas como archivadas");
      } else {
        debugPrint("No hay tareas nuevas de cursos archivados");
      }
    } catch (e) {
      debugPrint("Error marcando tareas archivadas: $e");
    }
  }
}
