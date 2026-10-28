import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/app_state.dart';
import '../widgets/brand_logos.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

      try {
        await context.read<AppState>().login(
          email: _email.text.trim(),
          password: _password.text,
          name: 'Petani Demo',
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        String message;

        switch (e.code) {
          case 'user-not-found':
          case 'invalid-credential':
            message = 'Email atau kata sandi salah.';
            break;
          case 'wrong-password':
            message = 'Kata sandi salah.';
            break;
          case 'invalid-email':
            message = 'Format email tidak valid.';
            break;
          case 'too-many-requests':
            message = 'Terlalu banyak percobaan. Coba lagi nanti.';
            break;
          default:
            message = 'Login gagal: ${e.message ?? e.code}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }

  void _demoLogin() {
  context.read<AppState>().loginDemo();
}

Future<void> _resetPassword() async {
  final email = _email.text.trim();

  if (email.isEmpty || !email.contains('@')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Masukkan email terlebih dahulu.'),
      ),
    );
    return;
  }

  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Jika email terdaftar, instruksi reset kata sandi akan dikirim.',
        ),
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal mengirim email reset: ${e.message ?? e.code}'),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Center(
                      child: MikikoTechnologyLogo(height: 40),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Smart Farming',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pantau sensor, kelola irigasi, dan rawat tanaman Anda dari satu tempat.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Masukkan email yang valid' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 4) ? 'Minimal 4 karakter' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Lupa kata sandi?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Masuk'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _demoLogin,
                      icon: const Icon(Icons.agriculture),
                      label: const Text('Masuk cepat sebagai demo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'MVP demo — data sensor masih berupa simulasi lokal.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 30),
                    Divider(color: scheme.outlineVariant),
                    const SizedBox(height: 18),
                    Text(
                      'DIPAYUNGI KOMUNITAS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(child: PetaniMudaKerenLogo(height: 66)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
