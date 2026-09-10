import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Recuperar senha',
      subtitle: _sent
          ? 'Se existe uma conta com esse email, o link de troca chegou lá.'
          : 'Te mandamos um link pra criar uma senha nova.',
      children: [
        if (!_sent) ...[
          Form(
            key: _form,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email'),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email inválido' : null,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
              label: 'Enviar link', onPressed: _submit, loading: _loading),
        ] else
          PrimaryButton(
              label: 'Voltar', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
