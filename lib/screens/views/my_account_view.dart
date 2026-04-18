import 'package:flutter/material.dart';
import '../../main.dart';

class MyAccountView extends StatefulWidget {
  const MyAccountView({super.key});

  @override
  State<MyAccountView> createState() => _MyAccountViewState();
}

class _MyAccountViewState extends State<MyAccountView> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;

  // Edit form
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (mounted) setState(() { _profile = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _startEditing() {
    final p = _profile ?? {};
    _firstNameCtrl.text = p['first_name'] as String? ?? '';
    _middleNameCtrl.text = p['middle_name'] as String? ?? '';
    _lastNameCtrl.text = p['last_name'] as String? ?? '';
    _studentIdCtrl.text = p['student_id'] as String? ?? '';
    _contactCtrl.text = p['contact'] as String? ?? '';
    setState(() => _isEditing = true);
  }

  void _cancelEditing() => setState(() => _isEditing = false);

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = {
        'id': userId,
        'email': supabase.auth.currentUser?.email,
        'first_name': _firstNameCtrl.text.trim(),
        'middle_name': _middleNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'student_id': _studentIdCtrl.text.trim().isEmpty
            ? null
            : _studentIdCtrl.text.trim(),
        'role': 'admin',
        'contact': _contactCtrl.text.trim(),
      };
      await supabase.from('users').upsert(data);
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        _fetchProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = supabase.auth.currentUser;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.account_circle_rounded,
                      color: colorScheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'My Account',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (!_isEditing && !_isLoading && _error == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(
                          _profile == null ? 'Create Profile' : 'Edit Profile'),
                      onPressed: _startEditing,
                    ),
                  if (!_isEditing)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: _fetchProfile,
                    ),
                  if (_isEditing) ...[
                    if (_isSaving)
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else ...[
                      TextButton(
                          onPressed: _cancelEditing,
                          child: const Text('Cancel')),
                      const SizedBox(width: 4),
                      FilledButton(
                          onPressed: _saveProfile,
                          child: const Text('Save')),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // ── Content ─────────────────────────────────────────
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator()))
              else if (_error != null)
                _ErrorCard(error: _error!, onRetry: _fetchProfile)
              else if (_isEditing)
                _EditForm(
                  formKey: _formKey,
                  firstNameCtrl: _firstNameCtrl,
                  middleNameCtrl: _middleNameCtrl,
                  lastNameCtrl: _lastNameCtrl,
                  studentIdCtrl: _studentIdCtrl,
                  contactCtrl: _contactCtrl,
                )
              else if (_profile == null)
                _NoProfileCard(
                    authEmail: user?.email,
                    authId: user?.id,
                    onCreateProfile: _startEditing)
              else
                _AccountCard(profile: _profile!, authEmail: user?.email),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Form ─────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController middleNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController studentIdCtrl;
  final TextEditingController contactCtrl;

  const _EditForm({
    required this.formKey,
    required this.firstNameCtrl,
    required this.middleNameCtrl,
    required this.lastNameCtrl,
    required this.studentIdCtrl,
    required this.contactCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile Information',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: middleNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Middle Name',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: studentIdCtrl,
                decoration: const InputDecoration(
                    labelText: 'Student ID (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: contactCtrl,
                decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              Text(
                'Use Save / Cancel in the toolbar above.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Account Card (read view) ──────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String? authEmail;

  const _AccountCard({required this.profile, required this.authEmail});

  String _initials(Map<String, dynamic> p) {
    final f = p['first_name'] as String? ?? '';
    final l = p['last_name'] as String? ?? '';
    final s =
        '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
    return s.isNotEmpty ? s : '?';
  }

  String _fullName(Map<String, dynamic> p) {
    final parts = <String>[
      p['first_name'] as String? ?? '',
      p['middle_name'] as String? ?? '',
      p['last_name'] as String? ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Unknown User' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final p = profile;
    final email = authEmail ?? (p['email'] as String? ?? '—');
    final rawRole = (p['role'] as String?)?.isNotEmpty == true
        ? p['role'] as String
        : 'admin';
    final role = '${rawRole[0].toUpperCase()}${rawRole.substring(1)}';
    final studentId = p['student_id']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    _initials(p),
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fullName(p),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _RoleBadge(
                              role: role, colorScheme: colorScheme),
                          if (studentId != null) ...[
                            const SizedBox(width: 8),
                            _RoleBadge(
                                role: 'Student',
                                colorScheme: colorScheme,
                                secondary: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            _DetailRow(
                icon: Icons.fingerprint_rounded,
                label: 'User ID',
                value: (p['id'] as String?) ??
                    supabase.auth.currentUser?.id ??
                    '—'),
            _DetailRow(
                icon: Icons.badge_outlined,
                label: 'First Name',
                value: p['first_name'] as String? ?? '—'),
            _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Middle Name',
                value: p['middle_name'] as String? ?? '—'),
            _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Last Name',
                value: p['last_name'] as String? ?? '—'),
            if (studentId != null)
              _DetailRow(
                  icon: Icons.school_outlined,
                  label: 'Student ID',
                  value: studentId),
            _DetailRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Role',
                value: role),
            _DetailRow(
                icon: Icons.email_outlined, label: 'Email', value: email),
            _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: p['contact'] as String? ?? '—'),
          ],
        ),
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  final ColorScheme colorScheme;
  final bool secondary;
  const _RoleBadge(
      {required this.role,
      required this.colorScheme,
      this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: secondary
            ? colorScheme.secondaryContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(role.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: secondary
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onPrimaryContainer)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.outline),
          const SizedBox(width: 14),
          SizedBox(
              width: 140,
              child: Text(label,
                  style: TextStyle(
                      color: colorScheme.outline, fontSize: 14))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }
}

// ── No Profile Card ───────────────────────────────────────────────────────────

class _NoProfileCard extends StatelessWidget {
  final String? authEmail;
  final String? authId;
  final VoidCallback onCreateProfile;
  const _NoProfileCard(
      {this.authEmail, this.authId, required this.onCreateProfile});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined,
                size: 52, color: colorScheme.outline),
            const SizedBox(height: 14),
            Text('No profile record found',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Your account exists but has no profile row in the users table yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13),
            ),
            if (authEmail != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: authEmail!),
            ],
            if (authId != null) ...[
              const SizedBox(height: 4),
              _DetailRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Auth ID',
                  value: authId!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Profile'),
              onPressed: onCreateProfile,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined,
                size: 52, color: colorScheme.error),
            const SizedBox(height: 14),
            Text('Could not load profile',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
