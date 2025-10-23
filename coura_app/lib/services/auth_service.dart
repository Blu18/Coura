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

  final String TU_PUB_SUB_TOPIC_NAME =
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
    UserCredential userCredential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
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
        print(
          "El usuario no ha iniciado sesión con Google o revocó los permisos.",
        );
        return null;
      }

      final http.Client? client = await _googleSignIn.authenticatedClient();

      if (client == null) {
        print("Error: No se pudo crear el cliente autenticado.");
        return null;
      }

      return classroom.ClassroomApi(client);
    } catch (e) {
      print("Error al obtener el cliente de Classroom API: $e");
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
        print("El usuario canceló el inicio de sesión con Google.");
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
        print("¡Cuenta de Firebase vinculada con Google exitosamente!");

        await _handlePostLinkActions(googleUser, googleAuth);

        return googleUser;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        print("Esta cuenta de Google ya está vinculada (lo cual es correcto).");

        if (googleUser != null && googleAuth != null) {
          print(
            "Procediendo a registrar notificaciones para la cuenta ya vinculada...",
          );
          await _handlePostLinkActions(googleUser, googleAuth);
          return googleUser;
        } else {
          print(
            "Error: No se pudo obtener googleUser o googleAuth en el catch.",
          );
          return null;
        }
      }

      print("Error de Firebase al vincular: ${e.message}");
      return null;
    } catch (e) {
      print("Ocurrió un error inesperado al vincular: $e");
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
        print(
          "Error: No se recibió serverAuthCode. Verifica tu serverClientId.",
        );
        return;
      }

      // Necesitamos el Firebase ID token
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("Error: No hay usuario de Firebase logueado.");
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
        print("¡Éxito! Refresh token guardado en el backend.");
        await syncClassroomData();
      } else {
        print("Error al guardar token: ${response.body}");
      }
    } catch (e) {
      print("Error en _handlePostLinkActions: $e");
    }
  }

  Future<void> syncClassroomData() async {
    print("Iniciando sincronización de Classroom...");
    final db = FirebaseFirestore.instance;

    // A. Obtiene la API de Classroom (como ya lo hacías)
    final api = await getClassroomApi();
    if (api == null) {
      print("Error: No se pudo obtener la API de Classroom.");
      return;
    }

    // B. Obtiene el ID del usuario de Firebase
    final user = firebaseAuth.currentUser;
    if (user == null) {
      print("Error: No hay usuario logueado.");
      return;
    }

    try {
      // C. Obtiene la lista de cursos del usuario
      final courseListResponse = await api.courses.list(studentId: "me");
      final courses = courseListResponse.courses;

      if (courses == null || courses.isEmpty) {
        print("No se encontraron cursos.");
        return;
      }

      // D. Prepara un 'batch' para guardar todo en Firestore
      // Esto es mucho más rápido que guardar un documento a la vez
      final batch = db.batch();

      for (var course in courses) {
        final courseId = course.id!;
        print("Obteniendo tareas para el curso: ${course.name}");

        // E. Obtiene las tareas de CADA curso
        final courseworkResponse = await api.courses.courseWork.list(
          courseId,
          courseWorkStates: ["PUBLISHED"], // Solo tareas publicadas
          orderBy: "updateTime desc",
        );
        final assignments = courseworkResponse.courseWork;

        if (assignments != null) {
          for (var assignment in assignments) {
            // F. Define dónde se guardará la tarea en Firestore
            final docRef = db
                .collection('users')
                .doc(user.uid)
                .collection('assignments')
                .doc(assignment.id!);

            // G. Añade la tarea al 'batch'
            // .toJson() convierte el objeto de Google a un Map
            batch.set(docRef, assignment.toJson());
          }
        }
      }

      // H. Ejecuta todas las operaciones de guardado a la vez
      await batch.commit();
      print("¡Sincronización completada! Tareas guardadas en Firestore.");
    } catch (e) {
      print("Error durante la sincronización: $e");
    }
  }
}
