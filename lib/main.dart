import 'package:betfriends/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do Firebase (se estiver usando)
  await Firebase.initializeApp();
  runApp(const App());
}
