import 'dart:async';
import 'package:coura_app/services/gemini_service.dart';
import 'package:coura_app/utils/animations/app_animations.dart';
import 'package:coura_app/utils/animations/card_animation.dart';
import 'package:coura_app/utils/custom/buttons/classroom_button.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/app_images.dart';
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
  bool _botonAvanzarHabilitado = false;
  int _tareaActualIndex = 0;
  String? _planIdActual;
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
    await _verificarProgresoTareas();
    _escucharCambiosEnContador();
    _inicializado = true;
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

  void _hacerScrollAlFinal() {
    debugPrint('🎯 Programando scroll...');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 1500), () {
        if (mounted && _scrollController.hasClients) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          debugPrint('   Ejecutando scroll animado a: $maxExtent');

          _scrollController
              .animateTo(
                maxExtent,
                duration: Duration(milliseconds: 300), // ← Más rápido
                curve: Curves.easeOut, // ← Desaceleración al final
              )
              .then((_) {
                debugPrint(
                  '   ✅ Scroll completado a: ${_scrollController.position.pixels}',
                );
              });
        }
      });
    });
  }

  Future<void> _verificarEstadoBoton() async {
    try {
      debugPrint('🔍 Verificando estado inicial del botón...');

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

      final existePlan = await _geminiService.existePlanHoy(widget.userId!);
      debugPrint('📅 ¿Existe plan hoy? $existePlan');

      if (existePlan) {
        final planDoc = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('planes_diarios')
            .orderBy('fechaCreacion', descending: true)
            .limit(1)
            .get();

        if (planDoc.docs.isNotEmpty) {
          final planData = planDoc.docs.first.data();
          _ultimoContadorTareas =
              planData['contador_tareas_al_generar'] ?? contadorActualUsuario;
          _planIdActual = planDoc.docs.first.id;
          debugPrint(
            '📊 Contador cuando se generó el plan: $_ultimoContadorTareas',
          );

          _tareaActualIndex = planData['tarea_actual_index'] ?? 0;
          // ignore: unused_local_variable
          final planCompletado = planData['completado'] ?? false;

          setState(() {
            _botonHabilitado = false;
            _botonAvanzarHabilitado = !planCompletado;
          });
        } else {
          _ultimoContadorTareas = contadorActualUsuario;
          debugPrint(
            '📊 No se encontró doc del plan, usando contador actual: $_ultimoContadorTareas',
          );
        }
      } else {
        _ultimoContadorTareas = contadorActualUsuario;
        debugPrint(
          '📊 Sin plan existente, contador inicial: $_ultimoContadorTareas',
        );
        setState(() {
          _botonHabilitado = !existePlan;
          _botonAvanzarHabilitado = existePlan;
        });
      }

      debugPrint('🔘 Botón Crear Plan habilitado: $_botonHabilitado');
      debugPrint('🔘 Botón Avanzar habilitado: $_botonAvanzarHabilitado');
      debugPrint('📌 _ultimoContadorTareas final: $_ultimoContadorTareas');
    } catch (e) {
      debugPrint('❌ Error verificando estado del botón: $e');
    }
  }

  Future<void> _verificarProgresoTareas() async {
    if (_planIdActual == null) return;

    try {
      final planDoc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('planes_diarios')
          .doc(_planIdActual)
          .get();

      if (planDoc.exists) {
        final data = planDoc.data();
        _tareaActualIndex = data?['tarea_actual_index'] ?? 0;
        debugPrint('📍 Índice de tarea actual: $_tareaActualIndex');
      }
    } catch (e) {
      debugPrint('❌ Error verificando progreso: $e');
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
    } catch (e) {
      debugPrint('Error guardando mensaje: $e');
    }
  }

  Future<void> _generarPlan() async {
    debugPrint('🚀 Generando/Actualizando plan...');

    setState(() {
      _cargando = true;
    });

    final existePlanPrevio = await _geminiService.existePlanHoy(widget.userId!);

    if (existePlanPrevio) {
      await _guardarMensaje(
        '🔄 Actualizar plan con nuevas tareas',
        esUsuario: true,
      );
      _hacerScrollAlFinal();
      debugPrint('🔄 Existe plan previo, se eliminará y creará uno nuevo');

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

        final mensajesPlan = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('chat_mensajes')
            .where('tipo', whereIn: ['plan', 'plan_resumen', 'tarea_actual'])
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
      _hacerScrollAlFinal();
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection("assignments")
          .get();
      final assignmentsExist = snapshot.size > 0;
      if (!assignmentsExist) {
        await _guardarMensaje("⚠️No tienes tareas creadas!", esUsuario: false);
        await _guardarMensaje(
          "Sincroniza con Classroom⚙️",
          esUsuario: false,
        );
      } else {
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
          debugPrint('✅ Plan generado, resultado completo: $resultado');
          debugPrint('📋 planId en resultado: ${resultado['planId']}');

          // Mostrar solo el resumen del plan
          await _guardarMensaje(
            '✅ Plan generado exitosamente\n'
            '📊 Total: ${resultado['totalTareas']} tareas\n'
            '⏱️ Tiempo estimado: ${resultado['horasTotales'].toStringAsFixed(1)} horas\n\n'
            '${resultado['mensaje']}\n\n'
            '💡 Presiona "Avanzar" para comenzar con la primera tarea',
            esUsuario: false,
            tipo: 'plan_resumen',
          );

          final planId = resultado['planId'];
          if (planId != null) {
            await _firestore
                .collection('users')
                .doc(widget.userId)
                .collection('planes_diarios')
                .doc(planId)
                .update({
                  'contador_tareas_al_generar': contadorActual,
                  'tarea_actual_index': 0,
                });
            debugPrint('💾 Contador guardado en el plan: $contadorActual');

            setState(() {
              _planIdActual = planId;
            });
            debugPrint('✅ Plan ID asignado: $_planIdActual');
          }

          _ultimoContadorTareas = contadorActual;
          _tareaActualIndex = 0;
          debugPrint('📊 Contador local actualizado a: $_ultimoContadorTareas');

          setState(() {
            _botonHabilitado = false;
            _botonAvanzarHabilitado = true;
          });
        } else {
          if(!resultado['exito']) {
            await _guardarMensaje(
              resultado['mensaje'],
              esUsuario: false,
          );
          } else {
            await _guardarMensaje(
            '❌ ${resultado['error'] ?? 'Error desconocido'}',
            esUsuario: false,
          );
          }
          
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

  Future<void> _sincronizarEstadoTarea(String assignmentId) async {
    if (_planIdActual == null) return;

    try {
      // Buscar la tarea en el plan
      final tareasSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('planes_diarios')
          .doc(_planIdActual)
          .collection('tareas')
          .where('assignmentId', isEqualTo: assignmentId)
          .limit(1)
          .get();

      if (tareasSnapshot.docs.isNotEmpty) {
        // Obtener el estado de la tarea en assignments
        final assignmentDoc = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('assignments')
            .doc(assignmentId)
            .get();

        if (assignmentDoc.exists) {
          final completada = assignmentDoc.data()?['completed'] ?? false;

          // Actualizar en el plan
          await tareasSnapshot.docs.first.reference.update({
            'completada': completada,
          });

          debugPrint(
            '🔄 Estado sincronizado para tarea: $assignmentId - Completada: $completada',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error sincronizando estado: $e');
    }
  }

  Future<void> _avanzarTarea() async {
    debugPrint('🔍 Plan ID actual: $_planIdActual');

    if (_planIdActual == null) {
      debugPrint('❌ No hay plan activo');
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      // Obtener el plan actual
      final planDoc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('planes_diarios')
          .doc(_planIdActual)
          .get();

      if (!planDoc.exists) {
        await _guardarMensaje(
          '❌ No se encontró el plan activo',
          esUsuario: false,
        );
        return;
      }

      // Obtener tareas desde la subcolección
      final tareasSnapshot = await planDoc.reference
          .collection('tareas')
          .orderBy('orden')
          .get();

      final tareas = tareasSnapshot.docs.map((doc) => doc.data()).toList();

      if (_tareaActualIndex > tareas.length) {
        await _guardarMensaje(
          '🎉 ¡Felicidades! Has completado todas las tareas del día',
          esUsuario: false,
        );

        try {
          await _firestore.collection('users').doc(widget.userId).set({
            'planes_completados': FieldValue.increment(1),
            'racha': FieldValue.increment(1),
            'completado': true,
          }, SetOptions(merge: true));

          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('planes_diarios')
              .doc(_planIdActual)
              .set({
                'completado': true,
                'fecha_completado': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          debugPrint('✅ Contador de planes completados incrementado');
        } catch (e) {
          debugPrint('❌ Error incrementando contador: $e');
        }

        setState(() {
          _botonAvanzarHabilitado = false;
        });
        return;
      }
      final tareaActual = tareas[_tareaActualIndex];

      // Verificar si la tarea está completada en Firestore
      if (_tareaActualIndex > 0) {
        final tareaAnterior = tareas[_tareaActualIndex - 1];
        final assignmentIdAnterior = tareaAnterior['assignmentId'];

        await _sincronizarEstadoTarea(assignmentIdAnterior);

        final assignmentDoc = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('assignments')
            .doc(assignmentIdAnterior)
            .get();

        if (assignmentDoc.exists) {
          final assignmentData = assignmentDoc.data();
          final completada = assignmentData?['completada'] ?? false;

          if (!completada) {
            await _guardarMensaje(
              '⚠️ Debes completar la tarea actual antes de avanzar.\n\n'
              '📝 Marca como completada: "${tareaAnterior['nombreTarea']}"',
              esUsuario: false,
            );
            setState(() {
              _cargando = false;
            });
            return;
          }
        }
      }

      // Mostrar la tarea actual
      await _guardarMensaje('▶️ Avanzar a siguiente tarea', esUsuario: true);

      _hacerScrollAlFinal();

      await _guardarMensaje(
        'Tarea actual',
        esUsuario: false,
        tipo: 'tarea_actual',
        dataPlan: {
          'tarea': tareaActual,
          'index': _tareaActualIndex,
          'total': tareas.length,
          'planId': _planIdActual,
        },
      );

      // Actualizar el índice en el plan
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('planes_diarios')
          .doc(_planIdActual)
          .update({'tarea_actual_index': _tareaActualIndex + 1});

      setState(() {
        _tareaActualIndex++;
      });
    } catch (e) {
      await _guardarMensaje('❌ Error: ${e.toString()}', esUsuario: false);
      debugPrint('❌ Error en _avanzarTarea: $e');
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
                              Image.asset(CAppImages.applogo, scale: 1.8),
                              SizedBox(height: 20),
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
                              SizedBox(height: 200),
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
                        bottom: 100,
                      ),
                      itemCount: mensajes.length,
                      itemBuilder: (context, index) {
                        final mensaje = mensajes[index];

                        if (mensaje.tipo == 'tarea_actual' &&
                            mensaje.dataPlan != null) {
                          return TareaActualWidget(
                            tareaData: mensaje.dataPlan!['tarea'],
                            index: mensaje.dataPlan!['index'],
                            total: mensaje.dataPlan!['total'],
                            userId: widget.userId!,
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

          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.userId)
                .collection('chat_mensajes')
                .snapshots(),
            builder: (context, chatSnapshot) {
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

                  return FutureBuilder<List<String>>(
                    future: _combinedFutures,
                    builder: (context, futureSnapshot) {
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

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (_cargando ||
                          (tieneMensajes &&
                              !_botonHabilitado &&
                              !hayNuevasTareas))
                      ? null
                      : _generarPlan,
                  icon: Icon(
                    (tieneMensajes && hayNuevasTareas && !_botonHabilitado)
                        ? Icons.refresh
                        : Icons.remove_red_eye_outlined,
                  ),
                  label: Text('Crear Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightergreen,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: ElevatedButton.icon(
                  iconAlignment: IconAlignment.end,
                  onPressed:
                      (_cargando ||
                          !_botonAvanzarHabilitado ||
                          _botonHabilitado)
                      ? null
                      : _avanzarTarea,
                  icon: Icon(Icons.arrow_forward),
                  label: Text('Avanzar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _botonAvanzarHabilitado
                        ? AppColors.cerulean
                        : Colors.grey[300],
                    foregroundColor: _botonAvanzarHabilitado
                        ? Colors.white
                        : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

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

// Widget para mostrar tarea actual
class TareaActualWidget extends StatefulWidget {
  final Map<String, dynamic> tareaData;
  final int index;
  final int total;
  final String userId;

  const TareaActualWidget({
    Key? key,
    required this.tareaData,
    required this.index,
    required this.total,
    required this.userId,
  }) : super(key: key);

  @override
  State<TareaActualWidget> createState() => _TareaActualWidgetState();
}

class _TareaActualWidgetState extends State<TareaActualWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  bool _completada = false;

  @override
  void initState() {
    super.initState();
    _verificarEstadoTarea();
  }

  Future<void> _verificarEstadoTarea() async {
    try {
      final assignmentId = widget.tareaData['assignmentId'];
      if (assignmentId != null) {
        final doc = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('assignments')
            .doc(assignmentId)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _completada = data?['completed'] ?? false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error verificando estado de tarea: $e');
    }
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
    final nombreTarea = widget.tareaData['nombreTarea'] ?? '';
    final prioridad = widget.tareaData['prioridad'] ?? 'Media';
    final horasEstimadas = widget.tareaData['horasEstimadas'] ?? 0.0;
    final materia = widget.tareaData['materia'] ?? '';
    final motivacion = widget.tareaData['motivacion'] ?? '';
    final pasosSugeridos =
        (widget.tareaData['pasosSugeridos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('assignments')
          .doc(widget.tareaData['assignmentId'])
          .snapshots(),
      builder: (context, snapshot) {
        bool completada = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          completada = data?['completed'] ?? false;
        }

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
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 229, 245, 235),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con progreso
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.keppel.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tarea ${widget.index + 1} de ${widget.total}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.keppel,
                              ),
                            ),
                          ),
                          Spacer(),
                          if (completada)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Completada',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Nombre de la tarea
                      Text(
                        nombreTarea,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),

                      // Badges: Prioridad, Tiempo, Materia
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getColorPrioridad(
                                prioridad,
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: 14,
                                  color: _getColorPrioridad(prioridad),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  prioridad,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getColorPrioridad(prioridad),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cerulean.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.cerulean,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '$horasEstimadas hrs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.cerulean,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (materia.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.book,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    materia,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Motivación
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💡', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                motivacion,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Pasos sugeridos
                      if (pasosSugeridos.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          '📝 Pasos sugeridos:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.keppel,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...pasosSugeridos.asMap().entries.map((entry) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.keppel.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.keppel,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      SizedBox(height: 16),

                      // Instrucción
                      // Instrucción
                      if (!completada)
                        Row(
                          children: [
                            Expanded(
                              // ✅ Cambia Container por Expanded
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange[700],
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Marca esta tarea como completada para continuar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[900],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ClassroomButton(
                              bgColor: Colors.blue,
                              iconColor: Colors.white,
                              url:
                                  widget.tareaData['classroomLink'] ??
                                  "https://classroom.google.com/",
                            ),
                          ],
                        ),

                      SizedBox(height: 8),
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
      },
    );
  }
}
