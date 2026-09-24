import 'package:flutter/material.dart';

class Appbardaspartidas extends StatelessWidget {
  final VoidCallback? onVerTodasPressed;
  final bool isLive;

  const Appbardaspartidas({
    super.key,
    this.onVerTodasPressed,
    this.isLive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "PARTIDAS",
              style: TextStyle(
                color: Color(0xFF8E9CAE),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            if (isLive) ...[
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF00D084),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        GestureDetector(
          onTap: onVerTodasPressed ?? () {},
          child: const Text(
            "Ver todas",
            style: TextStyle(
              color: Color(0xFF00D084),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
