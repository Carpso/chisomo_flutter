import 'package:flutter/material.dart';

class AppIconSpinner extends StatelessWidget {
  final double size;
  final Color? color;

  const AppIconSpinner({super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(
            width: size * 0.55,
            height: size * 0.55,
            child: Image.asset(
              'assets/kingdom_sponsor_app_icon.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}