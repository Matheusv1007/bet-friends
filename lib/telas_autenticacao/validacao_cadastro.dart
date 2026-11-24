/// Validação do formulário de cadastro antes de enviar (KAN-25).
///
/// Repete só o formato das regras para que o usuário corrija os campos antes
/// de a conta ser criada no Firebase Auth: um username fora do formato,
/// recusado só depois, deixaria a conta sem perfil. Quem decide é o backend
/// (`functions/src/perfil/username.ts`), inclusive a unicidade do username.
/// Nome: 1 a 60 caracteres (schema §3.1). Username: 3 a 20 letras sem acento,
/// números ou "_" (RN-AUTH-003). Senha: ao menos 6 caracteres (RN-AUTH-005).
///
/// O resultado é um erro por campo, mostrado sob o próprio campo.
library;

const int nomeMaximo = 60;
const int senhaMinima = 6;

final _username = RegExp(r'^[A-Za-z0-9_]{3,20}$');

/// Primeiro problema de cada campo; `null` onde o valor está válido.
class ErrosDoCadastro {
  const ErrosDoCadastro({
    this.nome,
    this.username,
    this.email,
    this.senha,
    this.confirmacao,
  });

  final String? nome;
  final String? username;
  final String? email;
  final String? senha;
  final String? confirmacao;

  bool get temErro =>
      nome != null ||
      username != null ||
      email != null ||
      senha != null ||
      confirmacao != null;
}

String? _validarNome(String nome) {
  final n = nome.trim();
  if (n.isEmpty) return 'Informe seu nome completo.';
  if (n.length > nomeMaximo) {
    return 'O nome deve ter no máximo $nomeMaximo caracteres.';
  }
  return null;
}

String? _validarUsername(String username) {
  final u = username.trim();
  if (u.isEmpty) return 'Informe um nome de usuário.';
  if (!_username.hasMatch(u)) {
    return 'O username deve ter de 3 a 20 caracteres: letras sem acento, '
        'números ou "_".';
  }
  return null;
}

String? _validarEmail(String email) {
  final e = email.trim();
  if (e.isEmpty) return 'Informe seu e-mail.';
  if (e.contains(' ') || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(e)) {
    return 'E-mail inválido.';
  }
  return null;
}

String? _validarSenha(String senha) {
  if (senha.isEmpty) return 'Informe uma senha.';
  if (senha.length < senhaMinima) {
    return 'A senha deve ter pelo menos $senhaMinima caracteres.';
  }
  return null;
}

String? _validarConfirmacao(String senha, String confirmacao) {
  if (confirmacao.isEmpty) return 'Confirme a senha.';
  if (senha != confirmacao) return 'As senhas não conferem.';
  return null;
}

/// Problemas do nome de exibição e do username.
ErrosDoCadastro validarPerfil({required String nome, required String username}) =>
    ErrosDoCadastro(nome: _validarNome(nome), username: _validarUsername(username));

/// Problemas do formulário completo.
ErrosDoCadastro validarCadastro({
  required String nome,
  required String username,
  required String email,
  required String senha,
  required String confirmacao,
}) =>
    ErrosDoCadastro(
      nome: _validarNome(nome),
      username: _validarUsername(username),
      email: _validarEmail(email),
      senha: _validarSenha(senha),
      confirmacao: _validarConfirmacao(senha, confirmacao),
    );
