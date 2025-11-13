import 'package:coura_app/services/gemini_service.dart';
import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
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
    _verificarEstadoBoton();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _verificarEstadoBoton() async {
    final existePlan = await _geminiService.existePlanHoy(widget.userId!);
    setState(() {
      _botonHabilitado = !existePlan;
    });
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
      print('Error guardando mensaje: $e');
    }
  }

  Future<void> _generarPlan() async {
    setState(() {
      _cargando = true;
    });

    await _guardarMensaje(
      '🤖 Generar mi plan de estudio del día',
      esUsuario: true,
    );

    try {
      final resultado = await _geminiService.generarPlanDiario(widget.userId!);

      if (resultado['exito'] == true) {
        await _guardarMensaje(
          '✅ Plan generado exitosamente\n'
          '📊 Total: ${resultado['totalTareas']} tareas\n'
          '⏱️ Tiempo estimado: ${resultado['horasTotales'].toStringAsFixed(1)} horas\n\n'
          '${resultado['mensaje']}',
          esUsuario: false,
        );

        await _guardarMensaje(
          'Plan interactivo del día',
          esUsuario: false,
          tipo: 'plan',
          dataPlan: resultado,
        );

        setState(() {
          _botonHabilitado = false;
        });
      } else {
        await _guardarMensaje(
          '❌ ${resultado['error'] ?? 'Error desconocido'}',
          esUsuario: false,
        );
      }
    } catch (e) {
      await _guardarMensaje('❌ Error: ${e.toString()}', esUsuario: false);
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  Future<void> _limpiarChat() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar conversación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar todos los mensajes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final mensajes = await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('chat_mensajes')
            .get();

        final batch = _firestore.batch();
        for (var doc in mensajes.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversación eliminada')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar mensajes')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Planificar tareas',
          style: CTextStyle.headlineLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.lapizlazuli,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _limpiarChat,
            tooltip: 'Limpiar conversación',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
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
                    child: CircularProgressIndicator(color: AppColors.cerulean),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error cargando mensajes'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                child: Text(
                                  '¡Hola! Estoy listo para organizar tu día.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),                        
                      ],
                    ),
                  );
                }

                final mensajes = snapshot.data!.docs
                    .map((doc) => MensajeChat.fromFirestore(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ))
                    .toList();

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = mensajes[index];

                    if (mensaje.tipo == 'plan' && mensaje.dataPlan != null) {
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
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_cargando || !_botonHabilitado) ? null : _generarPlan,
                        icon: Icon(Icons.remove_red_eye_outlined),
                        label: Text('Vizualizar Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightergreen,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_botonHabilitado)
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
        mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                color: esUsuario ? AppColors.cerulean : Color.fromARGB(255, 229, 245, 235),
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
                      Icon(Icons.calendar_today, color: AppColors.keppel, size: 16),
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
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getColorPrioridad(tarea.prioridad).withOpacity(0.15),
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
                                    Icon(Icons.access_time, size: 14, color: AppColors.cerulean),
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
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                                        style: TextStyle(fontSize: 12, color: Colors.black),
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
                                      ...tarea.pasosSugeridos.asMap().entries.map((entry) {
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: 4, left: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: AppColors.keppel.withOpacity(0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${entry.key + 1}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.keppel,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  entry.value,
                                                  style: TextStyle(fontSize: 11, color: Colors.black87),
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