import 'package:coura_app/firebase_options.dart';
import 'package:coura_app/services/auth_layout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Configura el manejador de mensajes en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  _configurarNotificaciones(); 

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Archivo .env cargado correctamente');

    if (dotenv.env["GEMINI_API_KEY"] == null) {
      debugPrint('⚠️ GEMINI_API_KEY no encontrada en .env');
    }
  } catch (e) {
    debugPrint('❌ Error al cargar .env: $e');
  }
  
  runApp(const MainApp());
}

void _configurarNotificaciones() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📲 Notificación recibida en foreground:');
    debugPrint('   Título: ${message.notification?.title}');
    debugPrint('   Cuerpo: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📲 Notificación tocada, abriendo app:');
    debugPrint('   Data: ${message.data}');
    
    final route = message.data['route'] ?? '/home';
    
    Future.delayed(Duration(milliseconds: 500), () {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(route);
      }
    });
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      debugPrint('📲 App abierta desde notificación:');
      debugPrint('   Data: ${message.data}');
      
      final route = message.data['route'] ?? '/home';
      
      Future.delayed(Duration(seconds: 1), () {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed(route);
        }
      });
    }
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Coura",
      showPerformanceOverlay: false,
      navigatorKey: navigatorKey,
      home: const AuthLayout(),
      routes: {
        '/home': (context) => const AuthLayout(),
      },
    );
  }
}