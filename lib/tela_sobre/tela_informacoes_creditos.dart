import 'package:flutter/material.dart';

import '../tema/tema.dart';
import '../widgets/componentes.dart';

/// Tela de Informações e Créditos do Aplicativo (KAN-54; RNF-011, RNF-012, D-015).
///
/// Apresenta as informações mínimas do produto e a atribuição legal obrigatória
/// ao provedor de dados de futebol ([RNF-011]):
/// "Dados fornecidos por football-data.org".
///
/// A atribuição e os dados são estáticos e locais, permanecendo disponíveis
/// independentemente do estado do provedor ou de conexão com a internet.
///
/// Conforme [RNF-012], os escudos são exibidos pela URL do provedor, sem cópia nem
/// armazenamento; o app não distribui imagens de terceiros.
class TelaInformacoesCreditos extends StatelessWidget {
  const TelaInformacoesCreditos({super.key});

  /// Texto de atribuição obrigatória exigido por RNF-011.
  static const String textoAtribuicaoProvedor =
      'Dados fornecidos por football-data.org';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: const Key('appbar_informacoes_creditos'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Informações e créditos'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            EspacosApp.margemDaTela,
            EspacosApp.e8,
            EspacosApp.margemDaTela,
            EspacosApp.e32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identificação do aplicativo
              Column(
                children: [
                  const LogoBetFriends(
                    key: Key('app_nome'),
                    variante: VarianteDoLogo.vertical,
                    altura: 96,
                  ),
                  const SizedBox(height: EspacosApp.e12),
                  Text(
                    'Versão 1.0.0 (MVP)',
                    key: const Key('app_versao'),
                    style: TextoApp.secundario.copyWith(
                      fontWeight: FontWeight.w600,
                      color: CoresApp.texto,
                    ),
                  ),
                  const SizedBox(height: EspacosApp.e4),
                  const Text(
                    'Desafios e palpites esportivos entre amigos',
                    textAlign: TextAlign.center,
                    style: TextoApp.secundario,
                  ),
                ],
              ),
              const SizedBox(height: EspacosApp.e24),

              // ATRIBUIÇÃO OBRIGATÓRIA (RNF-011)
              const TituloDeSecao('Créditos de dados'),
              const SizedBox(height: EspacosApp.e8),
              Card(
                key: const Key('card_atribuicao_provedor'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(EspacosApp.e16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Texto exato exigido pelo critério de aceitação (RNF-011)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: EspacosApp.e12,
                          vertical: EspacosApp.e12,
                        ),
                        decoration: const BoxDecoration(
                          color: CoresApp.superficie2,
                          borderRadius: RaiosApp.bordaChip,
                        ),
                        child: Text(
                          textoAtribuicaoProvedor,
                          key: const Key('texto_atribuicao_football_data'),
                          style: TextoApp.corpoForte.copyWith(
                            color: CoresApp.texto,
                          ),
                        ),
                      ),
                      const SizedBox(height: EspacosApp.e12),
                      const Text(
                        'As informações de partidas de futebol, competições, resultados e '
                        'calendários exibidas no aplicativo são obtidas a partir dos serviços '
                        'da API football-data.org.',
                        style: TextoApp.secundario,
                      ),
                      const SizedBox(height: EspacosApp.e8),
                      Text(
                        'Esta atribuição permanece disponível de forma permanente e independente '
                        'do estado de conexão ou disponibilidade do provedor externo.',
                        key: const Key('nota_disponibilidade_atribuicao'),
                        style: TextoApp.minimo.copyWith(
                          color: CoresApp.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: EspacosApp.e24),

              // PROPRIEDADE INTELECTUAL E LICENCIAMENTO (RNF-012, D-015)
              const TituloDeSecao('Licenciamento e escudos'),
              const SizedBox(height: EspacosApp.e8),
              Card(
                key: const Key('card_propriedade_intelectual'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(EspacosApp.e16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Os escudos dos clubes são marcas de seus respectivos titulares e '
                        'são exibidos a partir do provedor de dados (football-data.org), '
                        'sem cópia nem armazenamento pelo app. O BetFriends é um projeto '
                        'acadêmico, sem fins comerciais.',
                        key: Key('texto_licenciamento_escudos'),
                        style: TextoApp.secundario,
                      ),
                      const SizedBox(height: EspacosApp.e8),
                      Text(
                        'Quando o provedor não informa o escudo ou ele não pode ser '
                        'carregado, o time é identificado pelo nome e por um ícone de '
                        'escudo padronizado.',
                        style: TextoApp.minimo.copyWith(
                          color: CoresApp.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: EspacosApp.e24),

              // ESCOPO DO MVP (D-015)
              const TituloDeSecao('Finalidade do aplicativo'),
              const SizedBox(height: EspacosApp.e8),
              const Card(
                key: Key('card_escopo_mvp'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(EspacosApp.e16),
                  child: Text(
                    'O BetFriends foi desenvolvido exclusivamente para fins de entretenimento '
                    'e interação social entre amigos. O saldo de BetCoins é meramente virtual '
                    'e não possui valor monetário, não havendo compras com dinheiro real nem apostas financeiras.',
                    key: Key('texto_finalidade_app'),
                    style: TextoApp.secundario,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
