import 'package:flutter/material.dart';

class CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // 1. Empieza en la esquina superior izquierda (0,0)
    path.lineTo(0, size.height * 0.9); // Baja hasta el 40% de la altura

    // 2. Dibuja la curva
    // El primer punto (control point) define la 'profundidad' de la curva.
    // El segundo punto (end point) define dónde termina la curva.
    path.quadraticBezierTo(
      size.width * 0.5, // Punto de control X (a la mitad del ancho)
      size.height * 1.1, // Punto de control Y (más abajo para la curva)
      size.width, // Punto final X (a la derecha)
      size.height *
          0.9, // Punto final Y (a la misma altura que el inicio de la curva)
    );

    // 3. Completa la parte superior recta
    path.lineTo(size.width, 0); // Sube a la esquina superior derecha
    path.close(); // Cierra el camino de vuelta a (0,0) para formar la figura

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    // Devuelve 'false' si el clip no necesita cambiar
    return false;
  }
}