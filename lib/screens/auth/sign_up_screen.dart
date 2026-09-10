import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';
import 'auth_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUp(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Criar conta',
      subtitle: 'Começa a registrar suas cartas em segundos.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Como te chamar'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Digite um nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Email inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration:
                    const InputDecoration(hintText: 'Senha (mín. 6)'),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Pelo menos 6 caracteres'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
            label: 'Criar conta', onPressed: _submit, loading: _loading),
      ],
    );
  }
}
