import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:library_core/library_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;
    if (!ref.read(isDemoProvider)) await ref.read(pushServiceProvider).stop();
    await ref.read(authGatewayProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider).value;
    final loans = ref.watch(activeLoansProvider).value?.length ?? 0;
    final history = ref.watch(historyProvider).value?.length ?? 0;
    final settings = ref.watch(settingsProvider).value ?? const LibrarySettings();
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              MemberAvatar(member: member, radius: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(member?.name ?? '', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(member?.phone ?? '', style: t.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  if ((member?.membershipId ?? '').isNotEmpty)
                    StatusPill('${member!.membershipId} · ${member.membershipType}', color: t.colorScheme.primary),
                ]),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/edit-profile')),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(label: 'Borrowed', value: '$loans')),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'Books read', value: '$history')),
          const SizedBox(width: 10),
          Expanded(
            child: _Stat(
              label: 'Fines due',
              value: formatMoney(member?.outstandingFines ?? 0, settings.currency),
              color: (member?.outstandingFines ?? 0) > 0 ? AppColors.danger : null,
              onTap: () => context.push('/fines'),
            ),
          ),
        ]),
        if (member?.status == MemberStatus.suspended)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color: AppColors.danger.withValues(alpha: 0.08),
              child: const ListTile(
                leading: Icon(Icons.block, color: AppColors.danger),
                title: Text('Membership suspended'),
                subtitle: Text('Please contact the library desk.'),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _Group(children: [
          _Item(Icons.qr_code_2_rounded, 'Digital membership card', () => context.push('/card')),
          _Item(Icons.receipt_long_outlined, 'Fines & payments', () => context.push('/fines')),
          _Item(Icons.notifications_outlined, 'Notifications', () => context.push('/notifications')),
          _Item(Icons.event_outlined, 'Events & workshops', () => context.push('/events')),
          _Item(Icons.add_shopping_cart_outlined, 'Suggest a book', () => context.push('/requests')),
        ]),
        const SizedBox(height: 12),
        _Group(children: [
          _Item(Icons.local_library_outlined, 'About the library', () => context.push('/about')),
          _Item(Icons.feedback_outlined, 'Send feedback', () => context.push('/feedback')),
          _Item(Icons.settings_outlined, 'App settings', () => context.push('/settings')),
        ]),
        const SizedBox(height: 12),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Log out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            onTap: () => _logout(context, ref),
          ),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color, this.onTap});
  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, this.onTap);
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: onTap);
}

// ===========================================================================
// Edit profile (also used to complete the profile after first sign-in)
// ===========================================================================

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.onboarding = false});
  final bool onboarding;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;
  String _gender = '';
  final Set<String> _favourites = {};
  bool _saving = false;
  bool _loaded = false;

  void _load(Member m) {
    if (_loaded) return;
    _loaded = true;
    _name.text = m.name;
    _email.text = m.email;
    _address.text = m.address;
    _dob = m.dateOfBirth;
    _gender = m.gender;
    _favourites.addAll(m.favouriteCategories);
  }

  Future<void> _pickPhoto(Member m) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (file == null) return;
    try {
      await ref.read(repoProvider).uploadAvatar(m.id, await file.readAsBytes());
      showSnack('Photo updated');
    } catch (e) {
      showSnack(errorText(e), error: true);
    }
  }

  Future<void> _save(Member m) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(repoProvider).updateProfile(m.copyWith(
            name: _name.text,
            email: _email.text,
            address: _address.text,
            dateOfBirth: _dob,
            gender: _gender,
            favouriteCategories: _favourites.toList(),
          ));
      if (!widget.onboarding && mounted) {
        showSnack('Profile saved');
        context.pop();
      }
    } catch (e) {
      showSnack(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(memberProvider).value;
    final cats = ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    if (member == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _load(member);

    return Scaffold(
      appBar: AppBar(title: Text(widget.onboarding ? 'Complete your profile' : 'Edit profile'), automaticallyImplyLeading: !widget.onboarding),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: Stack(children: [
              MemberAvatar(member: member, radius: 48),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(icon: const Icon(Icons.camera_alt_outlined, size: 18), onPressed: () => _pickPhoto(member)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: member.phone,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Mobile (verified)', prefixIcon: Icon(Icons.verified_outlined)),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.alternate_email)),
            validator: (v) => (v ?? '').isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim()) ? null : 'Invalid email',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home_outlined)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dob ?? DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _dob = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of birth', prefixIcon: Icon(Icons.cake_outlined)),
                  child: Text(_dob == null ? 'Select' : formatDate(_dob)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender.isEmpty ? null : _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? ''),
              ),
            ),
          ]),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Favourite genres', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in cats)
                FilterChip(
                  label: Text(c.name),
                  selected: _favourites.contains(c.slug),
                  onSelected: (v) => setState(() => v ? _favourites.add(c.slug) : _favourites.remove(c.slug)),
                ),
            ]),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : () => _save(member),
            child: _saving ? const CircularProgressIndicator() : Text(widget.onboarding ? 'Continue' : 'Save'),
          ),
        ]),
      ),
    );
  }
}

// ===========================================================================
// Digital membership card
// ===========================================================================

class MembershipCardScreen extends ConsumerStatefulWidget {
  const MembershipCardScreen({super.key});

  @override
  ConsumerState<MembershipCardScreen> createState() => _MembershipCardScreenState();
}

class _MembershipCardScreenState extends ConsumerState<MembershipCardScreen> {
  @override
  void initState() {
    super.initState();
    // Max brightness hint for scanners is platform specific; keep screen awake-ish via haptic.
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(memberProvider).value;
    final s = ref.watch(settingsProvider).value ?? const LibrarySettings();
    return Scaffold(
      appBar: AppBar(title: const Text('Membership card')),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF12324A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Image.asset('assets/images/logo.png', width: 36, height: 36),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                    Text(m.membershipType.toUpperCase(), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 22),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(data: m.membershipId.isEmpty ? m.id : m.membershipId, size: 190),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(m.membershipId.isEmpty ? 'Membership number being assigned…' : m.membershipId,
                      style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _CardFact('Member since', formatDate(m.createdAt)),
                    const SizedBox(width: 24),
                    _CardFact('Valid till', m.membershipExpiresAt == null ? 'Lifetime' : formatDate(m.membershipExpiresAt)),
                    const SizedBox(width: 24),
                    _CardFact('Status', m.status.name),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              const Text('Show this QR code at the issue desk to borrow or return books.', textAlign: TextAlign.center),
            ]),
    );
  }
}

class _CardFact extends StatelessWidget {
  const _CardFact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]);
}
