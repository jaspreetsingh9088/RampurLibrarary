import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../widgets/common.dart';

final phoneAuthProvider = Provider<PhoneAuthService>((ref) => PhoneAuthService());

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  bool _agreed = true;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      showSnack('Please accept the terms to continue.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final sent = await ref.read(phoneAuthProvider).sendCode(normalizePhone(_phone.text));
      if (sent && mounted) context.push('/otp');
    } catch (e) {
      showSnack(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 32),
            Center(child: Image.asset('assets/images/logo.png', width: 84, height: 84)),
            const SizedBox(height: 28),
            Text('Welcome to\nRampur Library', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: 10),
            Text('Sign in with your mobile number. We\'ll send you a 6-digit code.',
                style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              style: const TextStyle(fontSize: 20, letterSpacing: 1.5, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Text('🇮🇳  +91', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: '98765 43210',
              ),
              validator: (v) => isValidIndianMobile(v ?? '') ? null : 'Enter a valid 10-digit mobile number',
              onFieldSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Wrap(children: [
                const Text('I agree to the library '),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('${AppConfig.siteUrl}/terms')),
                  child: Text('terms & privacy policy', style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _send,
              child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Send OTP'),
            ),
          ]),
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) t.cancel();
      if (mounted) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    setState(() => _loading = true);
    try {
      await ref.read(phoneAuthProvider).verifyCode(_code.text);
      // The router redirects once the auth state changes.
    } catch (e) {
      showSnack(errorText(e), error: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final auth = ref.read(phoneAuthProvider);
    try {
      await auth.sendCode(auth.phoneNumber!);
      showSnack('A new code is on its way.');
      _startTimer();
    } catch (e) {
      showSnack(errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final phone = ref.read(phoneAuthProvider).phoneNumber ?? '';
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Enter the code', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('We sent a 6-digit code to $phone', style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 30, letterSpacing: 14, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: '••••••', counterText: ''),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _verify,
          child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Verify & continue'),
        ),
        const SizedBox(height: 12),
        Center(
          child: _seconds > 0
              ? Text('Resend code in ${_seconds}s', style: t.textTheme.bodyMedium)
              : TextButton(onPressed: _resend, child: const Text('Resend code')),
        ),
        TextButton(onPressed: () => context.pop(), child: const Text('Change number')),
      ]),
    );
  }
}
