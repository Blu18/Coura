import 'dart:async';
import 'package:coura_app/services/gemini_service.dart';
import 'package:coura_app/utils/animations/app_animations.dart';
import 'package:coura_app/utils/animations/card_animation.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para mensajes
class MensajeChat {
  final String id;
  final String texto;
  final bool esUsuario;
  final DateTime timestamp;
  final String tipo;
  final Map<String, dynamic>? dataPlan;

  MensajeChat({
    required this.id,
    required this.texto,
    required this.esUsuario,
    required this.timestamp,
    this.tipo = 'texto',
    this.dataPlan,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'texto': texto,
      'esUsuario': esUsuario,
      'timestamp': Timestamp.fromDate(timestamp),
      'tipo': tipo,
      'dataPlan': dataPlan,
    };
  }

  factory MensajeChat.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime timestamp;
    if (data['timestamp'] != null) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    return MensajeChat(
      id: id,
      texto: data['texto'] ?? '',
      esUsuario: data['esUsuario'] ?? false,
      timestamp: timestamp,
      tipo: data['tipo'] ?? 'texto',
      dataPlan: data['dataPlan'],
    );
  }
}

class ChatIAScreen extends StatefulWidget {
  final String? userId;
  final String geminiApiKey;

  const ChatIAScreen({
    Key? key,
    required this.userId,
    required this.geminiApiKey,
  }) : super(key: key);

  @override
  State<ChatIAScreen> createState() => _ChatIAScreenState();
}

class _ChatIAScreenState extends State<ChatIAScreen> {
  late GeminiPlanificadorService _geminiService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _cargando = false;
  bool _botonHabilitado = true;
  final ScrollController _scrollController = ScrollController();
  int _ultimoContadorTareas = 0;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  bool _inicializado = false;
  late Future<List<String>> _combinedFutures;

  @override
  void initState() {
    super.initState();
    if (widget.userId == null || widget.userId!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Usuario no identificado')),
        );
      });
      return;
    }

    _geminiService = GeminiPlanificadorService(widget.geminiApiKey);
    _combinedFutures = Future.wait<String>([
      _geminiService.generarMotivacion(),
      _geminiService.generarDato(widget.userId!),
    ]);
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _verificarEstadoBoton();
    _escucharCambiosEnContador();
    _inicializado = true; // ← Marcar como inicializado
    debugPrint('✅ Inicialización completada');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _escucharCambiosEnContador() {
    debugPrint(
      '🎧 Iniciando listener del contador para usuario: ${widget.userId}',
    );

    _userSubscription = _firestore
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint('📡 Snapshot recibido - exists: ${snapshot.exists}');

            if (snapshot.exists) {
              final data = snapshot.data();
              final nuevoContador = data?['total_assignments'] ?? 0;

              debugPrint('📊 Valores:');
              debugPrint('   - Contador anterior: $_ultimoContadorTareas');
              debugPrint('   - Contador nuevo: $nuevoContador');
              debugPrint('   - Botón habilitado: $_botonHabilitado');
              debugPrint('   - Inicializado: $_inicializado');

              // Solo habilitar si ya pasó la inicialización y el contador aumentó
              if (_inicializado && nuevoContador > _ultimoContadorTareas) {
                debugPrint(
                  '✅ Contador AUMENTÓ después de inicialización - Habilitando botón',
                );
                setState(() {
                  _botonHabilitado = true;
                });
              } else if (!_inicializado) {
                debugPrint('⏳ Aún inicializando, ignorando cambio');
              } else if (nuevoContador == _ultimoContadorTareas) {
                debugPrint('➡️  Contador sin cambios');
              } else {
                debugPrint('⬇️  Contador disminuyó (raro)');
              }

              _ultimoContadorTareas = nuevoContador;
            } else {
              debugPrint('⚠️  Documento del usuario no existe');
            }
          },
          onError: (error) {
            debugPrint('❌ Error en listener: $error');
          },
        );
  }

  Future<void> _verificarEstadoBoton() async {
  try {
    debugPrint('🔍 Verificando estado inicial del botón...');

    // PRIMERO: Obtener el contador actual del usuario SIEMPRE
    final userDoc = await _firestore
        .collection('users')
        .doc(widget.userId)
        .get();

    int contadorActualUsuario = 0;
    if (userDoc.exists) {
      final data = userDoc.data();
      contadorActualUsuario = data?['total_assignments'] ?? 0;
      debugPrint('📊 Contador actual del usuario: $contadorActualUsuario');
    }

    // SEGUNDO: Verificar si ya existe un plan hoy
    final existePlan = await _geminiService.existePlanHoy(widget.userId!);
    debugPrint('📅 ¿Existe plan hoy? $existePlan');

    if (existePlan) {
      // Si existe un plan, obtener el contador que tenía cuando se generó
      final planDoc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('planes_diarios')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (planDoc.docs.isNotEmpty) {
        final planData = planDoc.docs.first.data();
        // Usar el contador guardado en el plan, o como fallback el contador actual (NO cero)
        _ultimoContadorTareas = planData['contador_tareas_al_generar'] ?? contadorActualUsuario;
        debugPrint(
          '📊 Contador cuando se generó el plan: $_ultimoContadorTareas',
        );
      } else {
        // Si no hay documento de plan, usar el contador actual
        _ultimoContadorTareas = contadorActualUsuario;
        debugPrint('📊 No se encontró doc del plan, usando contador actual: $_ultimoContadorTareas');
      }
    } else {
      // Si no existe plan, usar el contador actual
      _ultimoContadorTareas = contadorActualUsuario;
      debugPrint('📊 Sin plan existente, contador inicial: $_ultimoContadorTareas');
    }

    setState(() {
      _botonHabilitado = !existePlan;
    });

    debugPrint('🔘 Botón habilitado: $_botonHabilitado');
    debugPrint('📌 _ultimoContadorTareas final: $_ultimoContadorTareas');
  } catch (e) {
    debugPrint('❌ Error verificando estado del botón: $e');
  }
}

  Future<void> _guardarMensaje(
    String texto, {
    required bool esUsuario,
    String tipo = 'texto',
    Map<String, dynamic>? dataPlan,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('chat_mensajes')
          .add({
            'texto': texto,
            'esUsuario': esUsuario,
            'timestamp': FieldValue.serverTimestamp(),
            'tipo': tipo,
            'dataPlan': dataPlan,
          });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error guardando mensaje: $e');
    }
  }

  Future<void> _generarPlan() async {
    debugPrint('🚀 Generando/Actualizando plan...');

    setState(() {
      _cargando = true;
    });

    // Verificar si ya existe un plan hoy
    final existePlanPrevio = await _geminiService.existePlanHoy(widget.userId!);

    if (existePlanPrevio) {
      await _guardarMensaje(
        '🔄 Actualizar plan con nuevas tareas',
        esUsuario: true,
      );
      debugPrint('🔄 Existe plan previo, se eliminará y creará uno nuevo');

      // Eliminar el plan anterior
      try {
        final planDocs = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('planes_diarios')
            .where(
              'fecha',
              isEqualTo: DateTime.now().toIso8601String().split('T')[0],
            )
            .get();

        final batch = _firestore.batch();
        for (var doc in planDocs.docs) {
          batch.delete(doc.reference);
          debugPrint('🗑️ Eliminando plan anterior: ${doc.id}');
        }
        await batch.commit();

        // También eliminar mensajes del plan anterior del chat
        final mensajesPlan = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('chat_mensajes')
            .where('tipo', isEqualTo: 'plan')
            .get();

        final batchMensajes = _firestore.batch();
        for (var doc in mensajesPlan.docs) {
          batchMensajes.delete(doc.reference);
        }
        await batchMensajes.commit();
        debugPrint('🗑️ Mensajes de plan anterior eliminados');
      } catch (e) {
        debugPrint('⚠️ Error eliminando plan anterior: $e');
      }
    } else {
      await _guardarMensaje(
        '🤖 Generar mi plan de estudio del día',
        esUsuario: true,
      );
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection("assignments")
          .get();
      final assignmentsExist = snapshot.size > 0;
      if (!assignmentsExist) {
        await _guardarMensaje("⚠️No tienes tareas creada!", esUsuario: false);
        await _guardarMensaje(
          "Crea una nueva tarea o sincroniza con Classroom⚙️",
          esUsuario: false,
        );
      } else {
        // Obtener el contador ANTES de generar el plan
        final userDoc = await _firestore
            .collection('users')
            .doc(widget.userId)
            .get();

        int contadorActual = 0;
        if (userDoc.exists) {
          final data = userDoc.data();
          contadorActual = data?['total_assignments'] ?? 0;
        }
        debugPrint('📊 Contador al momento de generar: $contadorActual');

        final resultado = await _geminiService.generarPlanDiario(
          widget.userId!,
        );

        if (resultado['exito'] == true) {
          if (existePlanPrevio) {
            await _guardarMensaje(
              '✅ Plan actualizado exitosamente\n'
              '📊 Total: ${resultado['totalTareas']} tareas\n'
              '⏱️ Tiempo estimado: ${resultado['horasTotales'].toStringAsFixed(1)} horas\n\n'
              '${resultado['mensaje']}',
              esUsuario: false,
            );
          } else {
            await _guardarMensaje(
              '✅ Plan generado exitosamente\n'
              '📊 Total: ${resultado['totalTareas']} tareas\n'
              '⏱️ Tiempo estimado: ${resultado['horasTotales'].toStringAsFixed(1)} horas\n\n'
              '${resultado['mensaje']}',
              esUsuario: false,
            );
          }

          await _guardarMensaje(
            'Plan interactivo del día',
            esUsuario: false,
            tipo: 'plan',
            dataPlan: resultado,
          );

          // Guardar el contador en el documento del plan
          final planId = resultado['planId'];
          if (planId != null) {
            await _firestore
                .collection('users')
                .doc(widget.userId)
                .collection('planes_diarios')
                .doc(planId)
                .update({'contador_tareas_al_generar': contadorActual});
            debugPrint('💾 Contador guardado en el plan: $contadorActual');
          }

          // Actualizar el contador local
          _ultimoContadorTareas = contadorActual;
          debugPrint('📊 Contador local actualizado a: $_ultimoContadorTareas');

          debugPrint('🔒 Deshabilitando botón');
          setState(() {
            _botonHabilitado = false;
          });
        } else {
          await _guardarMensaje(
            '❌ ${resultado['error'] ?? 'Error desconocido'}',
            esUsuario: false,
          );
        }
      }
    } catch (e) {
      await _guardarMensaje('❌ Error: ${e.toString()}', esUsuario: false);
      debugPrint('❌ Error en _generarPlan: $e');
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Contenido principal
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(widget.userId)
                      .collection('chat_mensajes')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.cerulean,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error cargando mensajes'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 40,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Hola, estoy listo",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 2, 54, 10),
                                ),
                              ),
                              Text(
                                "para organizar tu día!",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 2, 54, 10),
                                ),
                              ),
                              SizedBox(height: 16),
                              AnimatedMotivationalCard(
                                future: _geminiService.generarMotivacion(),
                                backgroundColor: Color.fromARGB(
                                  255,
                                  229,
                                  245,
                                  235,
                                ),
                                loadingColor: Color.fromARGB(255, 2, 54, 10),
                                fontSize: 16,
                              ),
                              SizedBox(height: 16),
                              AnimatedMotivationalCard(
                                future: _geminiService.generarDato(
                                  widget.userId!,
                                ),
                                backgroundColor: Color.fromARGB(
                                  255,
                                  229,
                                  245,
                                  235,
                                ),
                                loadingColor: Color.fromARGB(255, 2, 54, 10),
                                fontSize: 16,
                              ),
                              SizedBox(height: 16),
                              FutureBuilder<List<String>>(
                                future: _combinedFutures,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.done &&
                                      snapshot.hasData) {
                                    return AnimatedCard(
                                      text:
                                          "Ahora, es momento de trabajar en tus tareas pendientes!✍️ ",
                                      backgroundColor: Color.fromARGB(
                                        255,
                                        229,
                                        245,
                                        235,
                                      ),
                                      fontSize: 16,
                                    );
                                  }
                                  return SizedBox.shrink();
                                },
                              ),
                              SizedBox(height: 80), // Espacio para el botón
                            ],
                          ),
                        ),
                      );
                    }

                    final mensajes = snapshot.data!.docs
                        .map(
                          (doc) => MensajeChat.fromFirestore(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .toList();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 100, // Espacio para el botón inferior
                      ),
                      itemCount: mensajes.length,
                      itemBuilder: (context, index) {
                        final mensaje = mensajes[index];

                        if (mensaje.tipo == 'plan' &&
                            mensaje.dataPlan != null) {
                          return PlanDiarioWidget(
                            planData: mensaje.dataPlan!,
                            userId: widget.userId!,
                            geminiService: _geminiService,
                          );
                        }

                        return ChatMessage(
                          texto: mensaje.texto,
                          esUsuario: mensaje.esUsuario,
                          timestamp: mensaje.timestamp,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_cargando)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.cerulean),
                      SizedBox(width: 16),
                      Text('Procesando...'),
                    ],
                  ),
                ),
            ],
          ),

          // Botón animado que se mueve del centro hacia abajo
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.userId)
                .collection('chat_mensajes')
                .snapshots(),
            builder: (context, chatSnapshot) {
              // Determinar si hay mensajes en el chat
              final tieneMensajes =
                  chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty;

              return StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(widget.userId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final data =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  final contadorActual = data?['total_assignments'] ?? 0;
                  final hayNuevasTareas =
                      contadorActual > _ultimoContadorTareas;

                  // Si hay mensajes, siempre mostrar el botón (abajo)
                  // Si no hay mensajes, mostrar solo cuando los futures estén listos (centro)
                  return FutureBuilder<List<String>>(
                    future: _combinedFutures,
                    builder: (context, futureSnapshot) {
                      // Mostrar el botón si:
                      // 1. Hay mensajes (ya se inició conversación) O
                      // 2. No hay mensajes pero los futures están completos
                      final mostrarBoton =
                          tieneMensajes ||
                          (futureSnapshot.connectionState ==
                              ConnectionState.done);

                      if (!mostrarBoton) {
                        return SizedBox.shrink();
                      }

                      return AnimatedPositioned(
                        duration: Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        // Posición vertical: centro o abajo según si hay mensajes
                        bottom: tieneMensajes
                            ? 16
                            : MediaQuery.of(context).size.height * 0.175,
                        left: 16,
                        right: 16,
                        child: _buildButtonContainer(
                          hayNuevasTareas,
                          contadorActual,
                          tieneMensajes,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButtonContainer(
    bool hayNuevasTareas,
    int contadorActual,
    bool tieneMensajes,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tieneMensajes ? Colors.grey[100] : Colors.transparent,
        boxShadow: tieneMensajes
            ? [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ]
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alerta de nuevas tareas (solo si hay mensajes)
          if (tieneMensajes && hayNuevasTareas && !_botonHabilitado)
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Tienes ${contadorActual - _ultimoContadorTareas} tarea${(contadorActual - _ultimoContadorTareas) > 1 ? 's' : ''} nueva${(contadorActual - _ultimoContadorTareas) > 1 ? 's' : ''}! Actualiza tu plan.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Botón principal
          ElevatedButton.icon(
            onPressed:
                (_cargando ||
                    (tieneMensajes && !_botonHabilitado && !hayNuevasTareas))
                ? null
                : _generarPlan,
            icon: Icon(
              (tieneMensajes && hayNuevasTareas && !_botonHabilitado)
                  ? Icons.refresh
                  : Icons.remove_red_eye_outlined,
            ),
            label: Text(
              (tieneMensajes && hayNuevasTareas && !_botonHabilitado)
                  ? 'Actualizar Plan'
                  : 'Visualizar Plan',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightergreen,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(double.infinity, 50),
            ),
          ),

          // Mensaje de confirmación (solo si hay mensajes)
          if (tieneMensajes && !_botonHabilitado && !hayNuevasTareas)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '✓ Ya generaste un plan hoy.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String texto;
  final bool esUsuario;
  final DateTime timestamp;

  const ChatMessage({
    Key? key,
    required this.texto,
    required this.esUsuario,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: esUsuario
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!esUsuario) ...[
            CircleAvatar(
              backgroundColor: Color.fromARGB(255, 229, 245, 235),
              child: Icon(Icons.smart_toy, color: AppColors.keppel, size: 20),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: esUsuario
                    ? AppColors.cerulean
                    : Color.fromARGB(255, 229, 245, 235),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    style: TextStyle(
                      color: esUsuario ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: esUsuario ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (esUsuario) ...[
            SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Color.fromARGB(255, 220, 240, 255),
              child: Icon(Icons.person, color: AppColors.cerulean, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class PlanDiarioWidget extends StatefulWidget {
  final Map<String, dynamic> planData;
  final String userId;
  final GeminiPlanificadorService geminiService;

  const PlanDiarioWidget({
    Key? key,
    required this.planData,
    required this.userId,
    required this.geminiService,
  }) : super(key: key);

  @override
  State<PlanDiarioWidget> createState() => _PlanDiarioWidgetState();
}

class _PlanDiarioWidgetState extends State<PlanDiarioWidget> {
  late List<TareaPlanificada> _tareas;

  @override
  void initState() {
    super.initState();
    final tareasData = widget.planData['tareas'] as List<dynamic>? ?? [];
    _tareas = tareasData
        .map((t) => TareaPlanificada.fromFirestore(t as Map<String, dynamic>))
        .toList();
  }

  Color _getColorPrioridad(String prioridad) {
    switch (prioridad.toLowerCase()) {
      case 'alta':
        return Colors.red;
      case 'media':
        return Colors.orange;
      case 'baja':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Color.fromARGB(255, 229, 245, 235),
            child: Icon(Icons.smart_toy, color: AppColors.keppel, size: 20),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 229, 245, 235),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppColors.keppel,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Plan del Día',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.keppel,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.keppel.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_tareas.length} tareas',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.keppel,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _tareas.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tarea = _tareas[index];
                      return Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 229, 245, 235),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.emerald,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${tarea.nombreTarea}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getColorPrioridad(
                                  tarea.prioridad,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tarea.prioridad,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getColorPrioridad(tarea.prioridad),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.cerulean,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Tiempo estimado: ${tarea.horasEstimadas} horas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (tarea.materia.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tarea.materia,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                            if (!tarea.completada)
                              Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.only(top: 8),
                                  title: Text(
                                    '💡 Ver detalles',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.keppel,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.amber.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        tarea.motivacion,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (tarea.pasosSugeridos.isNotEmpty) ...[
                                      SizedBox(height: 10),
                                      Text(
                                        '📝 Pasos sugeridos:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.keppel,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      ...tarea.pasosSugeridos
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 4,
                                                left: 4,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.keppel
                                                          .withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${entry.key + 1}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.keppel,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      entry.value,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.keppel.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 14, color: AppColors.keppel),
                        SizedBox(width: 6),
                        Text(
                          'Tiempo total: ${widget.planData['horasTotales'].toStringAsFixed(1)} horas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.keppel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
