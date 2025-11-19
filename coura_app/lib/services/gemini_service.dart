import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class TareaPlanificacion {
  final String id;
  final String nombre;
  final String descripcion;
  final DateTime? fechaLimite;
  final DateTime creadoEn;
  final String prioridad;
  final String materia;
  final bool completada;

  TareaPlanificacion({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaLimite,
    required this.creadoEn,
    required this.prioridad,
    required this.materia,
    required this.completada,
  });

  factory TareaPlanificacion.fromFirestore(String docId, Map<String, dynamic> data) {
    DateTime? fechalimite;
    if (data['fechaLimite'] != null) {
      fechalimite = (data['fechaLimite'] as Timestamp).toDate();
    } else {
      fechalimite = null;
    }

    return TareaPlanificacion(
      id: docId, 
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      fechaLimite: fechalimite,
      creadoEn: (data['creadoEn'] as Timestamp).toDate(),
      prioridad: data['prioridad'] ?? 'Media',
      materia: data['materia'] ?? '',
      completada: data['completada'] ?? false,
    );
  }
}

// Clase para tareas individuales del plan
class TareaPlanificada {
  final String nombreTarea;
  final String materia;
  final double horasEstimadas;
  final String motivacion;
  final List<String> pasosSugeridos;
  final String prioridad;
  final int orden;
  final bool completada;
  final String assignmentId;

  TareaPlanificada({
    required this.nombreTarea,
    required this.materia,
    required this.horasEstimadas,
    required this.motivacion,
    required this.pasosSugeridos,
    required this.prioridad,
    required this.orden,
    required this.assignmentId,
    this.completada = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'nombreTarea': nombreTarea,
      'materia': materia,
      'horasEstimadas': horasEstimadas,
      'motivacion': motivacion,
      'pasosSugeridos': pasosSugeridos,
      'prioridad': prioridad,
      'orden': orden,
      'completada': completada,
      'assignmentId': assignmentId,
    };
  }

  factory TareaPlanificada.fromFirestore(Map<String, dynamic> data) {
    return TareaPlanificada(
      nombreTarea: data['nombreTarea'] ?? '',
      materia: data['materia'] ?? '',
      horasEstimadas: (data['horasEstimadas'] ?? 0).toDouble(),
      motivacion: data['motivacion'] ?? '',
      pasosSugeridos: List<String>.from(data['pasosSugeridos'] ?? []),
      prioridad: data['prioridad'] ?? 'Media',
      orden: data['orden'] ?? 0,
      completada: data['completada'] ?? false,
      assignmentId: data['assignmentId'] ?? '',
    );
  }

  factory TareaPlanificada.fromJson(Map<String, dynamic> json) {
    return TareaPlanificada(
      nombreTarea: json['nombreTarea'] ?? '',
      materia: json['materia'] ?? '',
      horasEstimadas: (json['horasEstimadas'] ?? 0).toDouble(),
      motivacion: json['motivacion'] ?? '',
      pasosSugeridos: List<String>.from(json['pasosSugeridos'] ?? []),
      prioridad: json['prioridad'] ?? 'Media',
      orden: json['orden'] ?? 0,
      assignmentId: json['assignmentId'] ?? '', 
    );
  }
}

// Clase para el plan diario
class PlanDiario {
  final DateTime fechaCreacion;
  final int totalTareas;
  final double horasTotales;
  final String mensajeMotivacional;

  PlanDiario({
    required this.fechaCreacion,
    required this.totalTareas,
    required this.horasTotales,
    required this.mensajeMotivacional,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'totalTareas': totalTareas,
      'horasTotales': horasTotales,
      'mensajeMotivacional': mensajeMotivacional,
    };
  }

  factory PlanDiario.fromFirestore(Map<String, dynamic> data) {
    return PlanDiario(
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
      totalTareas: data['totalTareas'] ?? 0,
      horasTotales: (data['horasTotales'] ?? 0).toDouble(),
      mensajeMotivacional: data['mensajeMotivacional'] ?? '',
    );
  }
}

class GeminiPlanificadorService {
  final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int MAX_HORAS_DIA = 4;

  GeminiPlanificadorService(String apiKey)
    : _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
        ),
      );

  // Obtener tareas pendientes del usuario
  Future<List<TareaPlanificacion>> obtenerTareasPendientes(
    String userId,
  ) async {
    try {
      final ahora = DateTime.now();
      final dosMesesAtras = DateTime(ahora.year, ahora.month - 2, ahora.day);
      final unaSemanaAtras = ahora.subtract(const Duration(days: 7));

      final fechaLimiteStr = dosMesesAtras.toIso8601String();
      print('Fecha Límite enviada al query: $fechaLimiteStr');

      final tareasSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('assignments')
          .where('completada', isEqualTo: false)
          .get();

      // Filtrar en el cliente
      final tareasFiltradas = tareasSnapshot.docs.where((doc) {
        final data = doc.data();
        final classroomData = data['_classroom_data'] as Map<String, dynamic>?;

        final fechaLimite = data['fechaLimite'];
        DateTime? fechaVencimiento;

        if (fechaLimite is Timestamp) {
          fechaVencimiento = fechaLimite.toDate();
        } else if (fechaLimite is String) {
          fechaVencimiento = DateTime.tryParse(fechaLimite);
        }

        if (fechaVencimiento != null &&
            fechaVencimiento.isBefore(unaSemanaAtras)) {
          return false;
        }

        if (data['classroomId'] == null) return true;

        if (classroomData != null) {
          final creationTime = classroomData['creationTime'] as String?;
          final updateTime = classroomData['updateTime'] as String?;

          return (creationTime != null &&
                  creationTime.compareTo(fechaLimiteStr) >= 0) ||
              (updateTime != null && updateTime.compareTo(fechaLimiteStr) >= 0);
        }

        return false;
      }).toList();

      // Pasar el ID del documento
      return tareasFiltradas
          .map((doc) => TareaPlanificacion.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error obteniendo tareas: $e');
      return [];
    }
  }

  // Verificar si ya existe un plan para hoy
  Future<bool> existePlanHoy(String userId) async {
    try {
      final hoy = DateTime.now();
      final inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
      final finDelDia = inicioDelDia.add(Duration(days: 1));

      final planSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('planes_diarios')
          .where(
            'fechaCreacion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDelDia),
          )
          .where('fechaCreacion', isLessThan: Timestamp.fromDate(finDelDia))
          .limit(1)
          .get();

      return planSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error verificando plan existente: $e');
      return false;
    }
  }

  // Crear prompt mejorado para Gemini
  String _crearPromptMejorado(List<TareaPlanificacion> tareas) {
    final ahora = DateTime.now();
    final buffer = StringBuffer();

    buffer.writeln(
      'Eres un asistente de planificación académica experto. '
      'Debes crear un plan de estudio REALISTA y MANEJABLE para el día de hoy.',
    );
    buffer.writeln('\n=== REGLAS ESTRICTAS ===');
    buffer.writeln('1. El plan NO puede exceder $MAX_HORAS_DIA horas totales');
    buffer.writeln('2. Selecciona máximo 3-4 tareas prioritarias');
    buffer.writeln('3. Prioriza tareas según:');
    buffer.writeln('   - Fecha límite más cercana (peso: 40%)');
    buffer.writeln('   - Prioridad asignada (peso: 30%)');
    buffer.writeln('   - Complejidad estimada (peso: 30%)');
    buffer.writeln('4. Estima tiempos realistas (30 min a 2 horas por tarea)');
    buffer.writeln('\n=== TAREAS DISPONIBLES ===\n');

    final tareasOrdenadas = List<TareaPlanificacion>.from(tareas);
    tareasOrdenadas.sort((a, b) {
      final prioridadA = _valorPrioridad(a.prioridad);
      final prioridadB = _valorPrioridad(b.prioridad);

      if (prioridadA != prioridadB) return prioridadB.compareTo(prioridadA);

      if (a.fechaLimite != null && b.fechaLimite != null) {
        return a.fechaLimite!.compareTo(b.fechaLimite!);
      }
      return 0;
    });

    for (int i = 0; i < tareasOrdenadas.length; i++) {
      final tarea = tareasOrdenadas[i];
      final diasRestantes = tarea.fechaLimite?.difference(ahora).inDays;

      buffer.writeln('TAREA ${i + 1}:');
      buffer.writeln('  Nombre: ${tarea.nombre}');
      buffer.writeln('  Materia: ${tarea.materia}');
      buffer.writeln('  Prioridad: ${tarea.prioridad}');
      buffer.writeln(
        '  Fecha límite: ${_formatearFecha(tarea.fechaLimite)}'
        '${diasRestantes != null ? " ($diasRestantes días)" : ""}',
      );

      final descCorta = tarea.descripcion.length > 150
          ? '${tarea.descripcion.substring(0, 150)}...'
          : tarea.descripcion;
      buffer.writeln('  Descripción: $descCorta');
      buffer.writeln('  AssignmentId: ${tarea.id}'); // ← CORREGIDO
      buffer.writeln();
    }

    buffer.writeln('\n=== FORMATO DE RESPUESTA JSON REQUERIDO ===');
    buffer.writeln('''{
  "tareasPlanificadas": [
    {
      "nombreTarea": "Nombre de la tarea",
      "materia": "Nombre de la materia",
      "horasEstimadas": 1.5,
      "motivacion": "Por qué es importante y cómo te beneficia/Ejemplos de cómo científicos/ingenieros han usado estos conocimientos",
      "pasosSugeridos": [
        "Paso 1: acción concreta",
        "Paso 2: acción concreta",
        "Paso 3: acción concreta"
      ],
      "prioridad": "Alta/Media/Baja",
      "orden": 1,
      "assignmentId": "ID de tarea desde la lista de arriba"
    }
  ],
  "mensajeMotivacional": "Mensaje inspirador pero realista para el día"
}''');

    buffer.writeln('\n=== CRITERIOS DE SELECCIÓN ===');
    buffer.writeln('- Selecciona SOLO las tareas más urgentes/importantes');
    buffer.writeln(
      '- Suma de horasEstimadas NO debe superar $MAX_HORAS_DIA horas',
    );
    buffer.writeln('- Cada tarea debe tener 3-5 pasos concretos y accionables');
    buffer.writeln(
      '- La motivación debe ser específica y práctica (no genérica)',
    );
    buffer.writeln('- Ordena las tareas por prioridad (orden: 1, 2, 3...)');
    buffer.writeln('- IMPORTANTE: Copia EXACTAMENTE el assignmentId de la tarea que selecciones');

    return buffer.toString();
  }

  int _valorPrioridad(String prioridad) {
    switch (prioridad.toLowerCase()) {
      case 'alta':
        return 3;
      case 'media':
        return 2;
      case 'baja':
        return 1;
      default:
        return 2;
    }
  }

  String _formatearFecha(DateTime? fecha) {
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    if (fecha != null) {
      return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
    } else {
      return 'Sin fecha límite';
    }
  }

  Future<String> generarMotivacion() async {
    final String prompt =
        "Genera una frase motivadora corta y directa para un estudiante que necesita hacer sus tareas. "
        "Requisitos:\n"
        "- Una sola frase completa\n"
        "- Tono positivo y alentador\n"
        "- Máximo 15 palabras\n"
        "- Puedes usar emojis relevantes\n"
        "- Sin comillas, corchetes ni llaves\n"
        "- Responde ÚNICAMENTE con la frase, sin explicaciones\n\n"
        "Ejemplo: ¡Cada tarea completada es un paso hacia tus metas! 💪📚";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final motivacion = response.text ?? "¡Tú puedes lograrlo! 💪";

      final cleanResponse = motivacion
          .replaceAll(
            RegExp(r'[{}\[\]\""]'),
            '',
          )
          .trim();

      return cleanResponse;
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<String> generarDato(String userId) async {
    final materias = await _firestore
        .collection('users')
        .doc(userId)
        .collection('courses')
        .where('creado_en', isGreaterThanOrEqualTo: '2025-07-1T00:00:00.00Z')
        .get();

    final List<String> listaMaterias = materias.docs
        .map((documento) => documento.get('nombre') as String)
        .toList();

    final index = Random().nextInt(listaMaterias.length);

    final String prompt =
        "Genera una dato curioso corto y directo para un estudiante que necesita conocer de su materias: ${listaMaterias[index]}. "
        "Requisitos:\n"
        "- Un solo dato curioso\n"
        "- Interesante y util\n"
        "- Máximo 30 palabras\n"
        "- Puedes usar 1-2 emojis relevantes\n"
        "- Sin comillas, corchetes ni llaves\n"
        "- Responde ÚNICAMENTE con el dato, sin explicaciones\n\n"
        "Ejemplo: Los patrones de software mejoran la calidad y mantenibilidad del código! 💪📚";

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    final motivacion = response.text ?? "";

    final cleanResponse =
        "Dato curioso: ${motivacion.replaceAll(RegExp(r'[{}\[\]\""]'), '').trim()}";

    debugPrint("Respuesta: $cleanResponse");
    return cleanResponse;
  }

  // Generar plan con estructura JSON
  Future<Map<String, dynamic>> generarPlanDiario(String userId) async {
    try {
      final existePlan = await existePlanHoy(userId);
      if (existePlan) {}

      final tareas = await obtenerTareasPendientes(userId);

      if (tareas.isEmpty) {
        return {
          'exito': false,
          'mensaje': '🎉 ¡Excelente! No tienes tareas pendientes.',
        };
      }

      final prompt = _crearPromptMejorado(tareas);
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final planTexto = response.text ?? '{}';
      print('Respuesta de Gemini: $planTexto');

      Map<String, dynamic> planJson;
      try {
        final cleanJson = planTexto
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        planJson = jsonDecode(cleanJson);
      } catch (e) {
        print('Error parseando JSON: $e');
        throw Exception('La IA no generó un formato válido');
      }

      if (!planJson.containsKey('tareasPlanificadas')) {
        throw Exception('Respuesta inválida de la IA');
      }

      final tareasPlanificadas = (planJson['tareasPlanificadas'] as List)
          .map((t) => TareaPlanificada.fromJson(t))
          .toList();

      final mensajeMotivacional =
          planJson['mensajeMotivacional'] ??
          '¡Tú puedes lograr todo lo que te propongas!';

      final horasTotales = tareasPlanificadas.fold<double>(
        0.0,
        (sum, t) => sum + t.horasEstimadas,
      );

      if (horasTotales > MAX_HORAS_DIA) {
        throw Exception(
          'El plan generado excede las $MAX_HORAS_DIA horas permitidas',
        );
      }

      final planDiario = PlanDiario(
        fechaCreacion: DateTime.now(),
        totalTareas: tareasPlanificadas.length,
        horasTotales: horasTotales,
        mensajeMotivacional: mensajeMotivacional,
      );

      final planRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('planes_diarios')
          .add(planDiario.toFirestore());

      // Guardar cada tarea con su assignmentId
      final batch = _firestore.batch();
      for (final tarea in tareasPlanificadas) {
        final tareaRef = planRef.collection('tareas').doc();
        batch.set(tareaRef, tarea.toFirestore());
      }
      await batch.commit();

      debugPrint('📤 Retornando planId: ${planRef.id}');

      return {
        'exito': true,
        'planId': planRef.id,
        'totalTareas': tareasPlanificadas.length,
        'horasTotales': horasTotales,
        'mensaje': mensajeMotivacional,
        'tareas': tareasPlanificadas.map((t) => t.toFirestore()).toList(),
      };
    } catch (e) {
      print('Error generando plan: $e');
      return {'exito': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> obtenerPlanHoy(String userId) async {
    try {
      final hoy = DateTime.now();
      final inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
      final finDelDia = inicioDelDia.add(Duration(days: 1));

      final planSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('planes_diarios')
          .where(
            'fechaCreacion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDelDia),
          )
          .where('fechaCreacion', isLessThan: Timestamp.fromDate(finDelDia))
          .limit(1)
          .get();

      if (planSnapshot.docs.isEmpty) return null;

      final planDoc = planSnapshot.docs.first;
      final plan = PlanDiario.fromFirestore(planDoc.data());

      final tareasSnapshot = await planDoc.reference
          .collection('tareas')
          .orderBy('orden')
          .get();

      final tareas = tareasSnapshot.docs
          .map((doc) => TareaPlanificada.fromFirestore(doc.data()))
          .toList();

      return {'plan': plan, 'tareas': tareas, 'planDocId': planDoc.id};
    } catch (e) {
      print('Error obteniendo plan: $e');
      return null;
    }
  }

  Future<bool> marcarTareaCompletada(
    String userId,
    String planDocId,
    String tareaDocId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('planes_diarios')
          .doc(planDocId)
          .collection('tareas')
          .doc(tareaDocId)
          .update({'completada': true});

      return true;
    } catch (e) {
      print('Error marcando tarea: $e');
      return false;
    }
  }
}