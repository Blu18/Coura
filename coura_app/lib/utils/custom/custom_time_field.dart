import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class TimePickerFormField extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final bool isThisRequired;
  final String? Function(String?)? validator;

  const TimePickerFormField({
    super.key,
    required this.title,
    required this.controller,
    this.isThisRequired = false,
    this.validator,
  });

  @override
  State<TimePickerFormField> createState() => _TimePickerFormFieldState();
}

class _TimePickerFormFieldState extends State<TimePickerFormField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: <TextSpan>[
                TextSpan(text: widget.title),
                if (widget.isThisRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          TextFormField(
            controller: widget.controller,
            readOnly: true,
            decoration: InputDecoration(
              hintText: '--:--',
              hintStyle: CTextStyle.bodySmall,
              suffixIcon: const Icon(Icons.access_time), // Icono de reloj
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              border: outlineInputBorder,
              errorBorder: outlineInputBorder,
              enabledBorder: outlineInputBorder,
              focusedBorder: outlineInputBorder,
              disabledBorder: outlineInputBorder,
              focusedErrorBorder: outlineInputBorder,
            ),
            onTap:
                _selectTime, // Llamamos a la función para seleccionar la hora
            validator:
                widget.validator ??
                (value) {
                  if (widget.isThisRequired &&
                      (value == null || value.isEmpty)) {
                    return 'Este campo es requerido';
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime() async {
    // Usamos showTimePicker en lugar de showDatePicker
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              // Color principal (fondo del día seleccionado, cabecera)
              primary: AppColors.lapizlazuli,

              // Color del texto sobre el primario (ej: número del día seleccionado)
              onPrimary: Colors.white,

              // Color de fondo del calendario
              surface: Colors.white,

              // Color del texto de los días y botones
              onSurface: Colors.black87,

              secondary: AppColors.lapizlazuli,

              onSecondary: Colors.white
            ),
            // También puedes cambiar el estilo de los botones de texto
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    AppColors.lapizlazuli, // Color del texto de "OK" y "CANCEL"
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      // Usamos las localizaciones para formatear la hora correctamente (ej: 10:30 PM)
      if (mounted) {
        final String formattedTime = pickedTime.format(context);
        setState(() {
          widget.controller.text = formattedTime;
        });
      }
    }
  }

  OutlineInputBorder outlineInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
}
