import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Modelo de datos del usuario
class UserProfile {
  final String name;
  final String email;
  final int streak;
  final int tasksCompleted;
  final int tasksNotDelivered;
  final int tasksPending;
  final Set<String> unlockedBadges;
  final int currentWeek;

  UserProfile({
    required this.name,
    required this.email,
    required this.streak,
    required this.tasksCompleted,
    required this.tasksNotDelivered,
    required this.tasksPending,
    required this.unlockedBadges,
    this.currentWeek = 0,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // Método para obtener los datos del usuario desde Firestore
  Future<UserProfile> _getUserProfile() async {
    try {
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener documento del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      if (!userDoc.exists) {
        // Si no existe el documento, retornar valores por defecto
        return UserProfile(
          name: user!.displayName ?? "Usuario",
          email: user!.email ?? "Sin correo",
          streak: 0,
          tasksCompleted: 0,
          tasksNotDelivered: 0,
          tasksPending: 100,
          unlockedBadges: {},
          currentWeek: 0,
        );
      }

      final userData = userDoc.data()!;

      // Calcular semana actual
      final currentWeek = await _calculateCurrentWeek();

      print("!!!3");
      // Determinar emblemas desbloqueados
      final unlockedBadges = _calculateUnlockedBadges(
        userData['racha'] ?? 0,
        (userData['assignments_completed'] *
                100.0 /
                userData['total_assignments']) ??
            0,
        currentWeek,
        userData['assignments_pending'] ?? 100,
      );

      print("!!!4");
      return UserProfile(
        name: userData['name'] ?? user!.displayName ?? "Usuario",
        email: userData['email'] ?? user!.email ?? "Sin correo",
        streak: userData['racha'] ?? 0,
        tasksCompleted: userData['assignments_completed'] ?? 0,
        tasksNotDelivered: userData['assignments_not_completed'] ?? 0,
        tasksPending: userData['assignments_pending'] ?? 100,
        unlockedBadges: unlockedBadges,
        currentWeek: currentWeek,
      );
    } catch (e) {
      print('Error al cargar perfil: $e');
      // Retornar datos por defecto en caso de error
      return UserProfile(
        name: user?.displayName ?? "Usuario",
        email: user?.email ?? "Sin correo",
        streak: 0,
        tasksCompleted: 0,
        tasksNotDelivered: 0,
        tasksPending: 100,
        unlockedBadges: {},
        currentWeek: 0,
      );
    }
  }

  // Calcular semana actual
  Future<int> _calculateCurrentWeek() async {
    try {
      if (user == null) return 0;

      final firstTaskSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('assignments')
          .orderBy('_classroom_data.creationTime', descending: false)
          .limit(1)
          .get();

      if (firstTaskSnapshot.docs.isEmpty) {
        return 0;
      }

      final data = firstTaskSnapshot.docs.first.data();
      final creationField = data['_classroom_data']?['creationTime'];

      if (creationField == null) {
        print("⚠️ creationTime no existe");
        return 0;
      }

      late DateTime firstTaskDate;

      // Si es Timestamp (por si en un futuro MIGRAS)
      if (creationField is Timestamp) {
        firstTaskDate = creationField.toDate();
      }
      // Si es String (TU CASO ACTUAL)
      else if (creationField is String) {
        firstTaskDate = DateTime.parse(creationField);
      }
      // Cualquier otro tipo, evitamos crasheos
      else {
        print("⚠️ creationTime tiene un formato desconocido");
        return 0;
      }

      final now = DateTime.now();
      final weeksPassed = now.difference(firstTaskDate).inDays ~/ 7;

      print("weeksPassed: $weeksPassed");

      return weeksPassed + 1;
    } catch (e) {
      print('Error al calcular semana: $e');
      return 0;
    }
  }

  // Determinar emblemas desbloqueados
  Set<String> _calculateUnlockedBadges(
    int streak,
    double completedPercentage,
    int currentWeek,
    int pendingTasks,
  ) {
    Set<String> badges = {};

    // Semana productiva (7 días de racha)
    if (streak >= 7) badges.add('week');

    // Mes productivo (30 días de racha)
    if (streak >= 30) badges.add('month');

    // Semana actual
    if (currentWeek > 0) badges.add('current_week');

    // Porcentaje de entregas
    if (completedPercentage >= 80) {
      badges.add('percentage_80');
    } else if (completedPercentage >= 70) {
      badges.add('percentage_70');
    } else if (completedPercentage >= 60) {
      badges.add('percentage_60');
    }

    // Semestre completo (80 días de racha)
    if (streak >= 80) badges.add('semester');

    if(pendingTasks == 0) badges.add('no_pending');

    // Sin tareas pendientes (se validará con lógica adicional)
    // Este se puede activar cuando todas las tareas estén completas
    print("badges: $badges");
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: _getUserProfile(),
          builder: (context, snapshot) {
            // Mostrar loading mientras carga
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Colors.orange[600]),
              );
            }

            // Mostrar error si falla
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error al cargar el perfil',
                      style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Mostrar datos
            final userProfile = snapshot.data!;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección de perfil
                    _buildProfileSection(userProfile),

                    SizedBox(height: 30),

                    // Icono de racha
                    _buildStreakSection(userProfile),

                    SizedBox(height: 30),

                    // Barra de tareas entregadas
                    _buildTasksProgressSection(userProfile),

                    SizedBox(height: 30),

                    // Sección de emblemas
                    _buildBadgesSection(userProfile),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileSection(UserProfile userProfile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Foto de perfil
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 50, color: Colors.grey[600]),
            ),
          ],
        ),

        SizedBox(width: 20),

        // Información del usuario
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userProfile.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 5),
              Text(
                userProfile.email,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakSection(UserProfile userProfile) {
    // El tamaño aumenta con la racha
    double size = 100 + (userProfile.streak * 2.0).clamp(0, 50);

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[400]!, Colors.orange[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department,
              size: size * 0.4,
              color: Colors.white,
            ),
            Text(
              '${userProfile.streak}',
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksProgressSection(UserProfile userProfile) {
    final totalTasks =
        userProfile.tasksCompleted +
        userProfile.tasksNotDelivered +
        userProfile.tasksPending;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tareas entregadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 15),

          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 30,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calcular los anchos basados en el total de tareas
                  double completedWidth = totalTasks > 0
                      ? constraints.maxWidth *
                            (userProfile.tasksCompleted / totalTasks)
                      : 0;
                  double notDeliveredWidth = totalTasks > 0
                      ? constraints.maxWidth *
                            (userProfile.tasksNotDelivered / totalTasks)
                      : 0;
                  double pendingWidth = totalTasks > 0
                      ? constraints.maxWidth *
                            (userProfile.tasksPending / totalTasks)
                      : 0;

                  return Stack(
                    children: [
                      // Fondo gris
                      Container(
                        width: constraints.maxWidth,
                        color: Colors.grey[200],
                      ),
                      // Tareas completadas (verde) - inicia en 0
                      Positioned(
                        left: 0,
                        child: Container(
                          width: completedWidth,
                          height: 30,
                          color: Colors.green[400],
                        ),
                      ),
                      // Tareas no entregadas (rojo) - inicia después de las completadas
                      Positioned(
                        left: completedWidth,
                        child: Container(
                          width: notDeliveredWidth,
                          height: 30,
                          color: Colors.red[400],
                        ),
                      ),
                      // Tareas pendientes (amarillo/naranja) - inicia después de no entregadas
                      Positioned(
                        left: completedWidth + notDeliveredWidth,
                        child: Container(
                          width: pendingWidth,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          SizedBox(height: 15),

          // Leyendas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend(
                'Entregadas',
                '${(userProfile.tasksCompleted * 100.0 / totalTasks).toStringAsFixed(2)}%',
                Colors.green[400]!,
              ),
              _buildLegend(
                'No entregadas',
                '${(userProfile.tasksNotDelivered * 100.0 / totalTasks).toStringAsFixed(2)}%',
                Colors.red[400]!,
              ),
              _buildLegend(
                'Pendientes',
                '${(userProfile.tasksPending * 100.0 / totalTasks).toStringAsFixed(2)}%',
                Colors.grey[400]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, String percentage, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesSection(UserProfile userProfile) {
    final totalTasks =
        userProfile.tasksCompleted +
        userProfile.tasksNotDelivered +
        userProfile.tasksPending;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emblemas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 15),

          // Grid de emblemas
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              _buildBadge(
                userProfile,
                'week',
                Icons.local_fire_department,
                '7',
                'Una Semana\nProductiva',
              ),
              _buildBadge(
                userProfile,
                'month',
                Icons.calendar_today,
                '30',
                'Un Mes\nProductivo',
              ),
              _buildBadge(
                userProfile,
                'current_week',
                Icons.event_available,
                '${userProfile.currentWeek}',
                'Semana ${userProfile.currentWeek}',
              ),
              _buildBadge(
                userProfile,
                'percentage_80',
                Icons.show_chart,
                '${(((userProfile.tasksCompleted * 100.0 / totalTasks).toInt() / 10.0).toInt() * 10)}%',
                'Porcentaje\nde Entregas',
              ),
              _buildBadge(
                userProfile,
                'semester',
                Icons.school,
                '',
                'Semestre\nProductivo',
              ),
              _buildBadge(
                userProfile,
                'no_pending',
                Icons.check_circle,
                '',
                'Sin Tareas\nPendientes',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    UserProfile userProfile,
    String badgeId,
    IconData icon,
    String value,
    String label,
  ) {
    bool isUnlocked = userProfile.unlockedBadges.contains(badgeId);
    

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 35,
            color: isUnlocked ? Colors.orange[600] : Colors.grey[400],
          ),
          if (value.isNotEmpty) SizedBox(height: 5),
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.blue[800] : Colors.grey[500],
              ),
            ),
          SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: isUnlocked ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
