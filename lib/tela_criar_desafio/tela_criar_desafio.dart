import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../telas_principais/homePage.dart';

// TODO Implement this library.

class CriarDesafioScreen extends StatefulWidget {
  const CriarDesafioScreen({super.key});

  @override
  State<CriarDesafioScreen> createState() => _CriarDesafioScreenState();
}

class _CriarDesafioScreenState extends State<CriarDesafioScreen> {
  int valor = 50;
  int? partidaId = 1;
  final amigos = <int>{0};

  List<dynamic> partidas = [
    {'id': 1, 'casa': 'Flamengo', 'fora': 'Vasco', 'hora': 'Dom, 16:00'},
    {'id': 2, 'casa': 'SCCP', 'fora': 'Fluminense', 'hora': 'Dom, 18:30'},
  ];

  @override
  void initState() {
    super.initState();
    _buscarPartidas();
  }

  Future<void> _buscarPartidas() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.seudominio.com/partidas'),
      );
      if (res.statusCode == 200)
        setState(() => partidas = jsonDecode(res.body));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const card = Color(0xFFF5F5F5);
    const borda = Color(0xFFE0E0E0);
    const cinza = Color(0xFF7A7A7A);
    const textoPrincipal = Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: textoPrincipal),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Homepage()),
            (route) => false,
          ),
        ),
        title: const Text(
          'Criar Desafio',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textoPrincipal),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: borda, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              CircleAvatar(
                radius: 18,
                backgroundColor: card,
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: textoPrincipal,
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALDO DISPONÍVEL',
                    style: TextStyle(
                      color: cinza,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '1.500 fichas',
                    style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'ESCOLHA A PARTIDA',
            style: TextStyle(
              color: cinza,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...partidas.map((p) {
            final sel = partidaId == p['id'];
            return GestureDetector(
              onTap: () => setState(() => partidaId = p['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFE3F2FD) : card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Colors.blue : borda),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: sel ? Colors.blue : textoPrincipal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p['casa'],
                        style: TextStyle(
                          color: sel ? Colors.blue : textoPrincipal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          'x',
                          style: TextStyle(
                            color: cinza,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          p['hora'] ?? '',
                          style: const TextStyle(color: cinza, fontSize: 10),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Text(
                        p['fora'],
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: sel ? Colors.blue : textoPrincipal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: sel ? Colors.blue : textoPrincipal,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          const Text(
            'VALOR DO DESAFIO',
            style: TextStyle(
              color: cinza,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borda),
            ),
            child: Text(
              'fichas  $valor',
              style: const TextStyle(
                color: textoPrincipal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [10, 25, 50, 100].map((v) {
              final sel = valor == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => valor = v),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? Colors.blue : card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? Colors.blue : borda),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$v fichas',
                      style: TextStyle(
                        color: sel ? Colors.white : textoPrincipal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text(
            'CONVIDAR AMIGO',
            style: TextStyle(
              color: cinza,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            style: const TextStyle(color: textoPrincipal, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar amigo...',
              hintStyle: const TextStyle(color: cinza),
              prefixIcon: const Icon(Icons.search, color: cinza, size: 18),
              filled: true,
              fillColor: card,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borda),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borda),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...['Lucas Silva', 'Guilherme Santos'].asMap().entries.map((e) {
            final sel = amigos.contains(e.key);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borda),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: borda,
                    child: Icon(
                      Icons.person_outline,
                      size: 16,
                      color: textoPrincipal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(color: textoPrincipal),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => sel ? amigos.remove(e.key) : amigos.add(e.key),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: sel ? 6 : 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? Colors.green : borda,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: sel
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : const Text(
                              'Convidar',
                              style: TextStyle(color: textoPrincipal, fontSize: 11),
                            ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const Homepage()),
              (route) => false,
            ),
            child: const Text(
              'Enviar Desafio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
