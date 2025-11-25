import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ClassroomButton extends StatefulWidget {
  final Color bgColor;
  final Color iconColor;
  final String url;

  const ClassroomButton({
    super.key,
    required this.bgColor,
    required this.iconColor,
    required this.url,
  });

  @override
  State<ClassroomButton> createState() => _ClassroomButtonState();
}

class _ClassroomButtonState extends State<ClassroomButton> {
  Future<void> abrirTareaClassroom(String url) async {
    try {
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _mostrarError('No se puede abrir el link');
      }
    } catch (e) {
      _mostrarError('Error al abrir el link: $e');
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, // Añade tamaño fijo
      height: 36,
      decoration: BoxDecoration(
        color: widget.bgColor,
        shape: BoxShape.circle, // Esto lo hace circular
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => abrirTareaClassroom(widget.url),
          borderRadius: BorderRadius.circular(
            50,
          ), // Mismo radio para el efecto ripple
          child: Icon(Icons.open_in_new, color: widget.iconColor, size: 20),
        ),
      ),
    );
  }
}
