/// Validação do formulário de cadastro antes de enviar (KAN-25).
///
/// Repete só o formato das regras para que o usuário corrija os campos antes
/// de a conta ser criada no Firebase Auth: um username fora do formato,
/// recusado só depois, deixaria a conta sem perfil. Quem decide é o backend
/// (`functions/src/perfil/username.ts`), inclusive a unicidade do username.
/// Nome: 1 a 60 caracteres (schema §3.1). Username: 3 a 20 letras sem acento,
/// números ou "_" (RN-AUTH-003). Senha: ao menos 6 caracteres (RN-AUTH-005).
library;

const int nomeMaximo = 60;
const int senhaMinima = 6;

final _username = RegExp(r'^[A-Za-z0-9_]{3,20}$');

/// Primeiro problema do nome de exibição e do username, ou `null`.
String? validarPerfil({required String nome, required String username}) {
  final n = nome.trim();
  if (n.isEmpty || username.trim().isEmpty) {
    return 'Preencha o nome e o username.';
  }
  if (n.length > nomeMaximo) {
    return 'O nome deve ter no máximo $nomeMaximo caracteres.';
  }
  if (!_username.hasMatch(username.trim())) {
    return 'O username deve ter de 3 a 20 caracteres: letras sem acento, '
        'números ou "_".';
  }
  return null;
}

/// Primeiro problema do formulário completo, ou `null`.
String? validarCadastro({
  required String nome,
  required String username,
  required String email,
  required String senha,
  required String confirmacao,
}) {
  if (nome.trim().isEmpty ||
      username.trim().isEmpty ||
      email.trim().isEmpty ||
      senha.isEmpty ||
      confirmacao.isEmpty) {
    return 'Preencha todos os campos.';
  }
  final perfil = validarPerfil(nome: nome, username: username);
  if (perfil != null) return perfil;
  final e = email.trim();
  if (e.contains(' ') || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(e)) {
    return 'E-mail inválido.';
  }
  if (senha.length < senhaMinima) {
    return 'A senha deve ter pelo menos $senhaMinima caracteres.';
  }
  if (senha != confirmacao) {
    return 'As senhas não conferem.';
  }
  return null;
}
