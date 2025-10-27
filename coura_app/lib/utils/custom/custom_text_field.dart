import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class CustomField extends StatefulWidget {
  final String title;
  final String hintText;
  final TextEditingController controller;
  final bool isThisPassword;
  final bool isthisRequired;
  const CustomField({
    super.key,
    required this.title,
    required this.controller,
    this.hintText = '',
    this.isThisPassword = false,
    this.isthisRequired = false,
  });

  @override
  State<CustomField> createState() => _CustomFieldState();
}

class _CustomFieldState extends State<CustomField> {
  bool ispassClicked = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          widget.isthisRequired
              ? RichText(
                  text: TextSpan(
                    // Estilo por defecto para el texto, heredado por los hijos.
                    // Puedes cambiarlo por tu CTextStyle.bodyMedium si es necesario.
                    style: DefaultTextStyle.of(context).style,
                    children: <TextSpan>[
                      // Primera parte del texto: el título
                      TextSpan(text: widget.title),
                      // Segunda parte: el asterisco en color rojo
                      TextSpan(
                        text:
                            ' *', // El espacio es importante para separarlo del título
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : RichText(
                  text: TextSpan(
                    // Estilo por defecto para el texto, heredado por los hijos.
                    // Puedes cambiarlo por tu CTextStyle.bodyMedium si es necesario.
                    style: DefaultTextStyle.of(context).style,
                    children: <TextSpan>[
                      // Primera parte del texto: el título
                      TextSpan(text: widget.title),
                    ],
                  ),
                ),
          TextFormField(
            maxLines: widget.isThisPassword ? 1 : null,
            expands: false,
            controller: widget.controller,
            style: CTextStyle.bodyMedium,
            obscureText: ispassClicked && widget.isThisPassword,
            decoration: InputDecoration(
              suffixIcon: widget.isThisPassword
                  ? InkWell(
                      onTap: () {
                        setState(() {
                          ispassClicked = !ispassClicked;
                        });
                      },
                      child: Icon(
                        ispassClicked ? Icons.visibility : Icons.visibility_off,
                      ),
                    )
                  : null,
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
            validator: widget.isthisRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '${widget.title} no puede estar vacío.';
                    }
                    return null;
                  }
                : null,
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
