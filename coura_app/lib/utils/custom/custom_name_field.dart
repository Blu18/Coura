import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class CustomNameField extends StatefulWidget {
  final String title;
  final String hintText;
  final TextEditingController controller;
  const CustomNameField({
    super.key,
    required this.title,
    required this.controller,
    required this.hintText,
  });

  @override
  State<CustomNameField> createState() => _CustomNameFieldState();
}

class _CustomNameFieldState extends State<CustomNameField> {
  bool ispassClicked = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          TextFormField(
            controller: widget.controller,
            style: CTextStyle.bodyMedium,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              hintStyle: CTextStyle.bodySmall,
              hintText: widget.hintText,
              border: outlineInputBorder,
              errorBorder: outlineInputBorder,
              enabledBorder: outlineInputBorder,
              focusedBorder: outlineInputBorder,
              disabledBorder: outlineInputBorder,
              focusedErrorBorder: outlineInputBorder,
            ),
            autovalidateMode: AutovalidateMode
                .onUserInteraction, // Opcional: valida mientras el usuario escribe
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El nombre no puede estar vacío.';
              }

              final parts = value
                  .trim()
                  .split(' ')
                  .where((p) => p.isNotEmpty)
                  .toList();
              if (parts.length < 2) {
                return 'Por favor, ingresa nombre y apellido.';
              }

              return null; // Si retornas null, la validación es exitosa
            },
          ),
        ],
      ),
    );
  }

  OutlineInputBorder outlineInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
}
