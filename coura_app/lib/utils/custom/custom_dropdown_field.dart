import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class DropdownFormFieldCustom extends StatefulWidget {
  final String title;
  final TextEditingController controller; // Usamos un controller para guardar el valor
  final List<String> items; // La lista de opciones
  final String hintText;
  final bool isThisRequired;
  final String? Function(String?)? validator;

  const DropdownFormFieldCustom({
    super.key,
    required this.title,
    required this.controller,
    required this.items,
    this.hintText = 'Selecciona una opción',
    this.isThisRequired = false,
    this.validator,
  });

  @override
  State<DropdownFormFieldCustom> createState() => _DropdownFormFieldCustomState();
}

class _DropdownFormFieldCustomState extends State<DropdownFormFieldCustom> {
  String? _selectedValue;

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
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          DropdownButtonFormField<String>(
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
            initialValue: _selectedValue,
            style: CTextStyle.bodySmall,
            // Mapeamos la lista de Strings a una lista de DropdownMenuItem
            items: widget.items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: CTextStyle.bodySmall.copyWith(color: Colors.black87),),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedValue = newValue;
                widget.controller.text = newValue ?? ''; // Actualizamos el controller
              });
            },
            validator: widget.validator ??
                (value) {
                  if (widget.isThisRequired && value == null) {
                    return 'Debes seleccionar una opción';
                  }
                  return null;
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