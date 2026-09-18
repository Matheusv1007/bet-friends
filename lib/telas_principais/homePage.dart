import 'package:betfriends/provider/partidas_provider.dart';
import 'package:betfriends/widgets_homePage/appbarDasPartidas.dart';
import 'package:betfriends/widgets_homePage/cardDeDesafio.dart';
import 'package:betfriends/widgets_homePage/cardDePartidas.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  @override
  void initState() {
    super.initState();
    // Dispara a busca da API quando a tela é carregada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartidasProvider>().carregarPartidas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: double.infinity,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          child: Row(
            children: const [
              CircleAvatar(child: Icon(Icons.person)),
              SizedBox(width: 15),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Olá, Pedro"),
                  Text("1.500 fichas"),
                ],
              ),
              Spacer(),
              Text(
                "BetFriends",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<PartidasProvider>().carregarPartidas(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Carddedesafio(),
              const SizedBox(height: 16),
              const Appbardaspartidas(),
              const SizedBox(height: 10),

              // Seção reativa que escuta os dados da API
              Consumer<PartidasProvider>(
                builder: (context, partidasProvider, child) {
                  if (partidasProvider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (partidasProvider.errorMessage != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Erro ao carregar partidas: ${partidasProvider.errorMessage}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  partidasProvider.carregarPartidas(),
                              child: const Text("Tentar novamente"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (partidasProvider.partidas.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("Nenhuma partida encontrada no momento."),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: partidasProvider.partidas.length,
                    itemBuilder: (context, index) {
                      final partida = partidasProvider.partidas[index];
                      return Carddepartidas(partida: partida);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

