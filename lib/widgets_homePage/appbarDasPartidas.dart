import 'package:flutter/material.dart';

class Appbardaspartidas extends StatelessWidget {
  const Appbardaspartidas({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("PARTIDAS"),
        Spacer(),
        TextButton(
          onPressed: () {},
          child: Text("Ver Todas", style: TextStyle(color: Colors.green[700])),
        ),
      ],
    );
  }
}
