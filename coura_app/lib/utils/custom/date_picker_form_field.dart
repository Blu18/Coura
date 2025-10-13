import 'package:coura_app/utils/styles/app_colors.dart';
import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Necesitarás añadir 'intl' a tu pubspec.yaml

class DatePickerFormField extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final bool isThisRequired;
  final String? Function(String?)? validator; // Para validaciones personalizadas

  const DatePickerFormField({
    super.key,
    required this.title,
    required this.controller,
    this.isThisRequired = false,
    this.validator,
  });

  @override
  State<DatePickerFormField> createState() => _DatePickerFormFieldState();
}

class _DatePickerFormFieldState extends State<DatePickerFormField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          // Usamos RichText para el asterisco rojo, como en el ejemplo anterior
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: <TextSpan>[
                TextSpan(text: widget.title),
                if (widget.isThisRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          TextFormField(
            controller: widget.controller,
            readOnly: true, // Hacemos que el campo no se pueda editar manualmente
            decoration: InputDecoration(
              hintText: 'dd/mm/aaaa',
              hintStyle: CTextStyle.bodySmall,
              suffixIcon: const Icon(Icons.calendar_today),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              border: outlineInputBorder,
              errorBorder: outlineInputBorder,
              enabledBorder: outlineInputBorder,
              focusedBorder: outlineInputBorder,
              disabledBorder: outlineInputBorder,
              focusedErrorBorder: outlineInputBorder,
            ),
            onTap: _selectDate, // La magia sucede aquí
            validator: widget.validator ??
                (value) {
                  if (widget.isThisRequired && (value == null || value.isEmpty)) {
                    return 'Este campo es requerido';
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }

  // Función para mostrar el selector de fecha
  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), // Límite inferior de fechas
      lastDate: DateTime(DateTime.now().year + 10),  // Límite superior de fechas 
      builder: (context, child) {
      return Theme(
        // Usa .copyWith() para heredar el tema principal y solo cambiar lo que necesitas.
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
          ),
          // También puedes cambiar el estilo de los botones de texto
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lapizlazuli, // Color del texto de "OK" y "CANCEL"
            ),
          ),
        ),
        // Es crucial pasar el child que te da el builder.
        child: child!,
      );
    },
  );

    if (pickedDate != null) {
      // Formateamos la fecha a un string legible
      String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
      setState(() {
        widget.controller.text = formattedDate; // Actualizamos el texto del controlador
      });
    }
  }
  
  OutlineInputBorder outlineInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
}