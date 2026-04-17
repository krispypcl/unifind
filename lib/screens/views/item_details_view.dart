import 'package:flutter/material.dart';
import '../../main.dart';

class ItemDetailsView extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailsView({super.key, required this.item});

  @override
  State<ItemDetailsView> createState() => _ItemDetailsViewState();
}

class _ItemDetailsViewState extends State<ItemDetailsView> {
  late Map<String, dynamic> _item;
  bool _isEditing = false;
  bool _isSaving = false;

  // Extra joined data
  String? _submittedByName;
  String? _categoryName;
  bool _loadingExtra = true;

  // Edit form controllers
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _imageUrlCtrl;
  late String _editType;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
    _initControllers();
    _loadExtraData();
  }

  void _initControllers() {
    _titleCtrl = TextEditingController(text: _item['title'] as String? ?? '');
    _descriptionCtrl =
        TextEditingController(text: _item['description'] as String? ?? '');
    _locationCtrl =
        TextEditingController(text: _item['location'] as String? ?? '');
    _categoryCtrl =
        TextEditingController(text: _item['category_id']?.toString() ?? '');
    _imageUrlCtrl =
        TextEditingController(text: _item['image_url'] as String? ?? '');
    _editType = _item['type'] as String? ?? 'found';
  }

  Future<void> _loadExtraData() async {
    setState(() => _loadingExtra = true);
    try {
      final results = await Future.wait([
        _fetchUserName(_item['user_id']?.toString()),
        _fetchCategoryName(_item['category_id']),
      ]);
      if (mounted) {
        setState(() {
          _submittedByName = results[0];
          _categoryName = results[1];
          _loadingExtra = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  Future<String?> _fetchUserName(String? userId) async {
    if (userId == null) return null;
    try {
      final row = await supabase
          .from('users')
          .select('first_name, middle_name, last_name')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      final parts = <String>[
        row['first_name'] as String? ?? '',
        row['middle_name'] as String? ?? '',
        row['last_name'] as String? ?? '',
      ].where((s) => s.isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(' ');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchCategoryName(dynamic categoryId) async {
    if (categoryId == null) return null;
    try {
      final row = await supabase
          .from('categories')
          .select('name')
          .eq('id', categoryId)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _categoryCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _startEditing() => setState(() => _isEditing = true);

  void _cancelEditing() {
    _titleCtrl.text = _item['title'] as String? ?? '';
    _descriptionCtrl.text = _item['description'] as String? ?? '';
    _locationCtrl.text = _item['location'] as String? ?? '';
    _categoryCtrl.text = _item['category_id']?.toString() ?? '';
    _imageUrlCtrl.text = _item['image_url'] as String? ?? '';
    _editType = _item['type'] as String? ?? 'found';
    setState(() => _isEditing = false);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final newCategoryId = int.tryParse(_categoryCtrl.text);
      final oldCategoryId = _item['category_id'];
      final updates = {
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'category_id': newCategoryId,
        'image_url': _imageUrlCtrl.text.trim().isEmpty
            ? null
            : _imageUrlCtrl.text.trim(),
        'type': _editType,
      };
      // .select() forces execution and lets us detect if 0 rows were matched
      final result = await supabase
          .from('items')
          .update(updates)
          .eq('id', _item['id'])
          .select();
      if (result.isEmpty) {
        throw Exception(
            'No rows were updated — check that the item still exists and you have permission to edit it.');
      }
      if (mounted) {
        setState(() {
          _item = {..._item, ...updates};
          _isEditing = false;
        });
        // Re-fetch joined names if category changed (check BEFORE setState above)
        if (newCategoryId != oldCategoryId) _loadExtraData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _statusColor(String status, ColorScheme cs) => switch (status) {
        'open' => Colors.blue,
        'claimed' => Colors.orange,
        'closed' => Colors.blueGrey,
        _ => cs.outline,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isEditing
              ? 'Edit Item'
              : (_item['title'] as String? ?? 'Item Details'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) => IconButton(
              icon: Icon(mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              tooltip: mode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
              onPressed: () {
                themeModeNotifier.value = mode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
              },
            ),
          ),
          if (!_isEditing) ...[
            if (_item['status'] == 'claimed' ||
                _item['status'] == 'closed')
              Tooltip(
                message: 'Cannot edit a ${_item['status']} item',
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 20, color: Colors.grey),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Item',
                onPressed: _startEditing,
              ),
          ],
          if (_isEditing) ...[
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              TextButton(
                  onPressed: _cancelEditing, child: const Text('Cancel')),
              FilledButton(
                  onPressed: _saveChanges, child: const Text('Save')),
              const SizedBox(width: 8),
            ],
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                _isEditing ? _buildEditForm() : _buildDetails(isDark, colorScheme),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Read View ─────────────────────────────────────────────────────────────

  Widget _buildDetails(bool isDark, ColorScheme colorScheme) {
    final String? imageUrl = _item['image_url'] as String?;
    final bool isLost = _item['type'] == 'lost';
    final String status = _item['status'] as String? ?? '';
    final Color statusColor = _statusColor(status, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Image ──────────────────────────────────────────────
        GestureDetector(
          onTap: imageUrl != null && imageUrl.isNotEmpty
              ? () => _openFullscreen(context, imageUrl)
              : null,
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Stack(
              children: [
                imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 340,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _ImagePlaceholder(isDark: isDark),
                      )
                    : _ImagePlaceholder(isDark: isDark),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Tap to expand',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Title + Badges ─────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _item['title'] as String? ?? 'Untitled',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Badge(
                  label: (_item['type'] as String? ?? '').toUpperCase(),
                  color: isLost ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 6),
                _Badge(label: status.toUpperCase(), color: statusColor),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Details Card ───────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _InfoRow(
                    icon: Icons.tag_rounded,
                    label: 'Item ID',
                    value: _item['id']?.toString() ?? '—'),
                _RowDivider(),
                _InfoRow(
                    icon: Icons.description_outlined,
                    label: 'Description',
                    value: (_item['description'] as String?)
                                ?.trim()
                                .isNotEmpty ==
                            true
                        ? _item['description'] as String
                        : '—'),
                _RowDivider(),
                _InfoRow(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Type',
                    value: (_item['type'] as String? ?? '—').toUpperCase(),
                    valueColor: isLost ? Colors.red : Colors.green),
                _RowDivider(),
                _InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Status',
                    value: status.toUpperCase(),
                    valueColor: statusColor),
                _RowDivider(),
                _InfoRow(
                  icon: Icons.folder_outlined,
                  label: 'Category',
                  value: _loadingExtra
                      ? '...'
                      : (_categoryName ??
                          (_item['category_id']?.toString() ?? '—')),
                ),
                _RowDivider(),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _item['location'] as String? ?? '—'),
                _RowDivider(),
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Submitted By',
                  value: _loadingExtra
                      ? '...'
                      : (_submittedByName ??
                          (_item['user_id']?.toString() ?? '—')),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  _RowDivider(),
                  _InfoRow(
                      icon: Icons.image_outlined,
                      label: 'Image URL',
                      value: imageUrl,
                      mono: true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Edit Form ─────────────────────────────────────────────────────────────

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Category ID',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  prefixIcon: Icon(Icons.image_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('type_$_editType'),
                      initialValue: _editType,
                      decoration: const InputDecoration(
                          labelText: 'Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'lost', child: Text('Lost')),
                        DropdownMenuItem(
                            value: 'found', child: Text('Found')),
                      ],
                      onChanged: (v) => setState(() => _editType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45)),
                          const SizedBox(width: 6),
                          Text(
                            (_item['status'] as String? ?? 'open')
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  Icon(Icons.info_outline,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text(
                    'Status is managed by claim requests.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4)),
                  ),
                ],
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

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  final bool isDark;
  const _ImagePlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 300,
      width: double.infinity,
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : const Color(0xFFE8E8F0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 64, color: colorScheme.outline),
          const SizedBox(height: 10),
          Text('No image available',
              style: TextStyle(color: colorScheme.outline, fontSize: 15)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.outline),
          const SizedBox(width: 14),
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: colorScheme.outline, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
