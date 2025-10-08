import 'package:coura_app/utils/styles/text_style.dart';
import 'package:flutter/material.dart';

class CustomField extends StatefulWidget {
  final String title;
  final String hintText;
  final TextEditingController controller;
  final bool isThisPassword;
  const CustomField({
    super.key,
    required this.title,
    required this.controller,
    required this.hintText,
    this.isThisPassword = false,
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
          Text(widget.title, style: CTextStyle.bodyMediuimbold),
          TextFormField(
            controller: widget.controller,
            style: CTextStyle.bodyMedium,
            obscureText: ispassClicked ,
            decoration: InputDecoration(
              suffixIcon: widget.isThisPassword
                  ? InkWell(
                      onTap: () {
                        setState(() {
                          ispassClicked = !ispassClicked;
                        });
                      },
                      child: Icon( ispassClicked ? Icons.visibility : Icons.visibility_off),
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
          ),

          if(widget.isThisPassword)...[
            SizedBox(height: 10,),
            Align( 
              alignment: Alignment.centerRight,
              child: Text("¿Olvidaste tu contraseña?", style: CTextStyle.bodySmall.copyWith(color: const Color.fromARGB(255, 80, 80, 80)))
            )
          ]   
        ],
      ),
    );
  }

  OutlineInputBorder outlineInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
}
