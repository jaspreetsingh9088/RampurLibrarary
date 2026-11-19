import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(staffAuthProvider).signIn(_email.text.trim(), _password.text);
    } catch (e) {
      toast(errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      toast('Enter your email first.', error: true);
      return;
    }
    await guard(() => ref.read(staffAuthProvider).resetPassword(_email.text.trim()), success: 'Password reset email sent.');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final role = ref.watch(staffRoleProvider).value;
    final notStaff = user != null && role == StaffRole.none;
    final who = user?.email ?? '';
    final t = Theme.of(context);

    return Scaffold(
      body: Row(children: [
        if (MediaQuery.sizeOf(context).width > 900)
          Expanded(
            child: Container(
              color: brandPrimary,
              padding: const EdgeInsets.all(56),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/logo.png', width: 80, height: 80)),
                const SizedBox(height: 28),
                const Text('Rampur Library', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('Catalogue, circulation, members and notifications — all in one place.',
                    style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.5)),
              ]),
            ),
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Staff sign in', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('Use the account your administrator created for you.', style: t.textTheme.bodyMedium),
                      const SizedBox(height: 28),
                      if (ref.watch(isDemoProvider)) ...[
                        Card(
                          color: brandAccent.withValues(alpha: 0.15),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Demo mode — sample data, nothing is saved', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const SelectableText('Admin: admin@demo.com\nLibrarian: librarian@demo.com\nPassword: demo1234'),
                              TextButton(
                                onPressed: () {
                                  _email.text = 'admin@demo.com';
                                  _password.text = 'demo1234';
                                  _signIn();
                                },
                                child: const Text('Sign in as demo admin'),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (notStaff) ...[
                        Card(
                          color: dangerColor.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$who is not a staff account.', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const Text('Ask an admin to grant you access on the Staff page, then sign in again.'),
                              TextButton(onPressed: () => ref.read(staffAuthProvider).signOut(), child: const Text('Use another account')),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
                        validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => (v ?? '').length >= 6 ? null : 'At least 6 characters',
                        onFieldSubmitted: (_) => _signIn(),
                      ),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _reset, child: const Text('Forgot password?'))),
                      const SizedBox(height: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        onPressed: _busy ? null : _signIn,
                        child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
