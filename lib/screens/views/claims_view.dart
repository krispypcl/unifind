import 'package:flutter/material.dart';
import '../../main.dart';

String _userDisplayName(Map<String, dynamic> user) {
  final parts = <String>[
    user['first_name'] as String? ?? '',
    user['middle_name'] as String? ?? '',
    user['last_name'] as String? ?? '',
  ].where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? 'Unknown User' : parts.join(' ');
}

class ClaimsView extends StatefulWidget {
  const ClaimsView({super.key});

  @override
  State<ClaimsView> createState() => _ClaimsViewState();
}

class _ClaimsViewState extends State<ClaimsView> {
  List<Map<String, dynamic>> _claims = [];

  // item_id → {title, category_id, image_url, location}
  final Map<String, Map<String, dynamic>> _itemData = {};
  // claimant_id → full name
  final Map<String, String> _claimantNames = {};
  // category_id → name
  final Map<dynamic, String> _categoryNames = {};
  // categories available in current claim set (for filter dropdown)
  List<Map<String, dynamic>> _filterCategories = [];

  bool _isLoading = true;
  String? _error;

  // Filters
  String? _statusFilter;
  String? _dateFilter; // null | 'today' | 'week' | 'month'
  dynamic _categoryFilter; // null | category_id (int)

  // Notes controllers — only created for pending claims
  final Map<dynamic, TextEditingController> _notesCtrl = {};
  final Set<dynamic> _processingStatus = {};

  @override
  void initState() {
    super.initState();
    _fetchClaims();
  }

  @override
  void dispose() {
    for (final c in _notesCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchClaims() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final claimsData = await supabase
          .from('claims')
          .select()
          .order('created_at', ascending: false);

      final claims = List<Map<String, dynamic>>.from(claimsData);

      final itemIds = claims
          .map((c) => c['item_id'] as String?)
          .whereType<String>()
          .toSet();
      final claimantIds = claims
          .map((c) => c['claimant_id'] as String?)
          .whereType<String>()
          .toSet();

      // Fetch item data and claimant names in parallel
      final Future<List<Map<String, dynamic>>> itemsFuture = itemIds.isNotEmpty
          ? supabase
              .from('items')
              .select('id, title, category_id, image_url, location')
              .inFilter('id', itemIds.toList())
          : Future.value(const []);
      final Future<List<Map<String, dynamic>>> usersFuture = claimantIds.isNotEmpty
          ? supabase
              .from('users')
              .select('id, first_name, middle_name, last_name')
              .inFilter('id', claimantIds.toList())
          : Future.value(const []);
      final fetchResults = await Future.wait([itemsFuture, usersFuture]);

      final itemData = <String, Map<String, dynamic>>{};
      for (final item in fetchResults[0]) {
        itemData[item['id'] as String] = Map<String, dynamic>.from(item);
      }

      final claimantNames = <String, String>{};
      for (final user in fetchResults[1]) {
        claimantNames[user['id'] as String] = _userDisplayName(user);
      }

      // Fetch category names for the category IDs found in items
      final categoryIds = itemData.values
          .map((i) => i['category_id'])
          .where((id) => id != null)
          .toSet();
      final categoryNames = <dynamic, String>{};
      final filterCategories = <Map<String, dynamic>>[];
      if (categoryIds.isNotEmpty) {
        final catData = await supabase
            .from('categories')
            .select('id, name')
            .inFilter('id', categoryIds.toList());
        for (final cat in catData) {
          categoryNames[cat['id']] = cat['name'] as String? ?? 'Unknown';
          filterCategories.add({'id': cat['id'], 'name': cat['name']});
        }
        filterCategories.sort((a, b) =>
            (a['name'] as String).compareTo(b['name'] as String));
      }

      // Update notes controllers: preserve existing drafts, only add/remove as status changes
      final pendingIds = claims
          .where((c) => (c['status'] as String?) == 'pending')
          .map((c) => c['id'])
          .toSet();
      final toRemove = _notesCtrl.keys.where((id) => !pendingIds.contains(id)).toList();
      for (final id in toRemove) {
        _notesCtrl[id]!.dispose();
        _notesCtrl.remove(id);
      }
      for (final claim in claims) {
        if ((claim['status'] as String?) == 'pending') {
          _notesCtrl.putIfAbsent(
            claim['id'],
            () => TextEditingController(text: claim['admin_notes'] as String? ?? ''),
          );
        }
      }

      if (mounted) {
        setState(() {
          _claims = claims;
          _itemData
            ..clear()
            ..addAll(itemData);
          _claimantNames
            ..clear()
            ..addAll(claimantNames);
          _categoryNames
            ..clear()
            ..addAll(categoryNames);
          _filterCategories = filterCategories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(
      Map<String, dynamic> claim, String newStatus) async {
    final id = claim['id'];
    setState(() => _processingStatus.add(id));
    try {
      final updateData = <String, dynamic>{'status': newStatus};

      if (newStatus == 'pending') {
        // Clear admin notes when reverting to pending
        updateData['admin_notes'] = null;
      } else {
        // Save the notes alongside the approve/reject decision
        final notes = _notesCtrl[id]?.text.trim() ?? '';
        updateData['admin_notes'] = notes.isEmpty ? null : notes;
      }

      await supabase
          .from('claims')
          .update(updateData)
          .eq('id', id);

      if (newStatus == 'approved') {
        final itemId = claim['item_id'] as String?;
        if (itemId != null) {
          // Mark the item as claimed
          await supabase
              .from('items')
              .update({'status': 'claimed'})
              .eq('id', itemId);

          // Auto-reject all other pending claims on the same item
          await supabase
              .from('claims')
              .update({
                'status': 'rejected',
                'admin_notes':
                    'Automatically rejected by system - a claim on the same item has been approved.',
              })
              .eq('item_id', itemId)
              .eq('status', 'pending')
              .neq('id', id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claim marked as $newStatus.')),
        );
        await _fetchClaims();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingStatus.remove(id));
    }
  }

  Future<void> _addClaim(
      String itemId, String claimantId, String details) async {
    try {
      await supabase.from('claims').insert({
        'item_id': itemId,
        'claimant_id': claimantId,
        'claim_details': details.isEmpty ? null : details,
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim request created.')),
        );
        await _fetchClaims();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error creating claim: $e')));
      }
    }
  }

  void _showAddClaimDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddClaimDialog(onSubmit: _addClaim),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    return _claims.where((c) {
      // Status
      if (_statusFilter != null && c['status'] != _statusFilter) return false;

      // Date
      if (_dateFilter != null) {
        final raw = c['created_at'] as String?;
        final date = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
        if (date == null) return false;
        switch (_dateFilter) {
          case 'today':
            if (!(date.year == now.year &&
                date.month == now.month &&
                date.day == now.day)) { return false; }
          case 'week':
            if (date.isBefore(now.subtract(const Duration(days: 7)))) {
              return false;
            }
          case 'month':
            if (date.isBefore(now.subtract(const Duration(days: 30)))) {
              return false;
            }
        }
      }

      // Category
      if (_categoryFilter != null) {
        final itemId = c['item_id'] as String?;
        if (itemId == null) return false;
        final item = _itemData[itemId];
        if (item == null || item['category_id'] != _categoryFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pendingCount = _claims.where((c) => c['status'] == 'pending').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                color: colorScheme.primary, size: 26),
            const SizedBox(width: 10),
            Text(
              'Claims',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            if (!_isLoading && pendingCount > 0)
              _PendingBadge(count: pendingCount),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Claim'),
              onPressed: _showAddClaimDialog,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _fetchClaims,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Filter rows ──────────────────────────────────────────
        _buildFilterRow(colorScheme),
        const SizedBox(height: 16),

        // ── List ─────────────────────────────────────────────────
        Expanded(child: _buildList(colorScheme)),
      ],
    );
  }

  Widget _buildFilterRow(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
            children: [
              Text('Status:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              _Chip(
                  label: 'All',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null)),
              const SizedBox(width: 6),
              _Chip(
                  label: 'Pending',
                  selected: _statusFilter == 'pending',
                  color: Colors.orange,
                  onTap: () => setState(() => _statusFilter = 'pending')),
              const SizedBox(width: 6),
              _Chip(
                  label: 'Approved',
                  selected: _statusFilter == 'approved',
                  color: Colors.green,
                  onTap: () => setState(() => _statusFilter = 'approved')),
              const SizedBox(width: 6),
              _Chip(
                  label: 'Rejected',
                  selected: _statusFilter == 'rejected',
                  color: Colors.red,
                  onTap: () => setState(() => _statusFilter = 'rejected')),
              const SizedBox(width: 20),
              Container(
                  width: 1,
                  height: 20,
                  color: colorScheme.outlineVariant),
              const SizedBox(width: 20),
              Text('Date:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              _Chip(
                  label: 'All',
                  selected: _dateFilter == null,
                  onTap: () => setState(() => _dateFilter = null)),
              const SizedBox(width: 6),
              _Chip(
                  label: 'Today',
                  selected: _dateFilter == 'today',
                  onTap: () => setState(() => _dateFilter = 'today')),
              const SizedBox(width: 6),
              _Chip(
                  label: 'This week',
                  selected: _dateFilter == 'week',
                  onTap: () => setState(() => _dateFilter = 'week')),
              const SizedBox(width: 6),
              _Chip(
                  label: 'This month',
                  selected: _dateFilter == 'month',
                  onTap: () => setState(() => _dateFilter = 'month')),
              // Category dropdown (only when there are categories to filter)
              if (_filterCategories.isNotEmpty) ...[
                const SizedBox(width: 20),
                Container(
                    width: 1,
                    height: 20,
                    color: colorScheme.outlineVariant),
                const SizedBox(width: 20),
                Text('Category:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(width: 8),
                _CategoryDropdown(
                  categories: _filterCategories,
                  selectedId: _categoryFilter,
                  onChanged: (v) => setState(() => _categoryFilter = v),
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildList(ColorScheme colorScheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 52,
                color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Failed to load claims',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              onPressed: _fetchClaims,
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 52,
                color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No claims match the current filters.',
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          padding: const EdgeInsets.only(bottom: 24),
          itemBuilder: (context, index) {
            final claim = filtered[index];
            final id = claim['id'];
            final itemId = claim['item_id'] as String? ?? '';
            final claimantId = claim['claimant_id'] as String? ?? '';
            final status = claim['status'] as String? ?? 'pending';
            final item = _itemData[itemId];
            final categoryName = item != null
                ? _categoryNames[item['category_id']]
                : null;

            return _ClaimCard(
              claim: claim,
              itemData: item,
              categoryName: categoryName,
              claimantName: _claimantNames[claimantId] ?? 'Unknown User',
              notesCtrl: status == 'pending' ? _notesCtrl[id] : null,
              isProcessingStatus: _processingStatus.contains(id),
              onApprove: status == 'pending'
                  ? () => _updateStatus(claim, 'approved')
                  : null,
              onReject: status == 'pending'
                  ? () => _updateStatus(claim, 'rejected')
                  : null,
              onMarkPending: status != 'pending'
                  ? () => _updateStatus(claim, 'pending')
                  : null,
            );
          },
        ),
      ),
    );
  }
}

// ── Add Claim Dialog ──────────────────────────────────────────────────────────

class _AddClaimDialog extends StatefulWidget {
  final Future<void> Function(String itemId, String claimantId, String details)
      onSubmit;

  const _AddClaimDialog({required this.onSubmit});

  @override
  State<_AddClaimDialog> createState() => _AddClaimDialogState();
}

class _AddClaimDialogState extends State<_AddClaimDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detailsCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _users = [];
  String? _selectedItemId;
  String? _selectedClaimantId;
  bool _loadingData = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        // Only items with status='open' can be claimed
        supabase
            .from('items')
            .select('id, title')
            .eq('status', 'open')
            .order('title'),
        supabase
            .from('users')
            .select('id, first_name, middle_name, last_name')
            .order('first_name'),
      ]);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(results[0]);
          _users = List<Map<String, dynamic>>.from(results[1]);
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _selectedItemId!,
        _selectedClaimantId!,
        _detailsCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.assignment_add, size: 20),
          SizedBox(width: 8),
          Text('New Claim Request'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loadingData
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No open items available to claim.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey('item_$_selectedItemId'),
                        initialValue: _selectedItemId,
                        decoration: const InputDecoration(
                            labelText: 'Item (open only)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_2_outlined)),
                        hint: const Text('Select an item'),
                        items: _items
                            .map((item) => DropdownMenuItem<String>(
                                  value: item['id'] as String,
                                  child: Text(
                                    item['title'] as String? ?? 'Untitled',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedItemId = v),
                        validator: (v) =>
                            v == null ? 'Please select an item' : null,
                      ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('claimant_$_selectedClaimantId'),
                      initialValue: _selectedClaimantId,
                      decoration: const InputDecoration(
                          labelText: 'Claimant',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline_rounded)),
                      hint: const Text('Select a user'),
                      items: _users
                          .map((user) => DropdownMenuItem<String>(
                                value: user['id'] as String,
                                child: Text(
                                  _userDisplayName(user),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedClaimantId = v),
                      validator: (v) =>
                          v == null ? 'Please select a claimant' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _detailsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Claim Details (optional)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_submitting || _loadingData || _items.isEmpty)
              ? null
              : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ── Claim Card ────────────────────────────────────────────────────────────────

class _ClaimCard extends StatelessWidget {
  final Map<String, dynamic> claim;
  final Map<String, dynamic>? itemData;
  final String? categoryName;
  final String claimantName;
  final TextEditingController? notesCtrl;
  final bool isProcessingStatus;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onMarkPending;

  const _ClaimCard({
    required this.claim,
    required this.itemData,
    required this.categoryName,
    required this.claimantName,
    required this.notesCtrl,
    required this.isProcessingStatus,
    this.onApprove,
    this.onReject,
    this.onMarkPending,
  });

  static Color _statusColor(String s) => switch (s) {
        'pending' => Colors.orange,
        'approved' => Colors.green,
        'rejected' => Colors.red,
        _ => Colors.grey,
      };

  static IconData _statusIcon(String s) => switch (s) {
        'pending' => Icons.hourglass_empty_rounded,
        'approved' => Icons.check_circle_outline_rounded,
        'rejected' => Icons.cancel_outlined,
        _ => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = claim['status'] as String? ?? 'pending';
    final statusColor = _statusColor(status);
    final isPending = status == 'pending';
    final claimDetails = claim['claim_details'] as String? ?? '';
    final adminNotes = claim['admin_notes'] as String? ?? '';

    final itemTitle = itemData?['title'] as String? ?? 'Unknown Item';
    final imageUrl = itemData?['image_url'] as String?;
    final location = itemData?['location'] as String?;

    final createdAt = claim['created_at'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() : null;
    final dateStr = date != null
        ? '${date.month}/${date.day}/${date.year}'
        : '—';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left accent strip
            Container(width: 5, color: statusColor),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status + date ──────────────────────────────
                    Row(
                      children: [
                        Icon(_statusIcon(status),
                            size: 15, color: statusColor),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.5),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_today_outlined,
                            size: 12,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.4)),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Item info with thumbnail ────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 72,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _ThumbPlaceholder(isDark: isDark),
                                )
                              : _ThumbPlaceholder(isDark: isDark),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoLine(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Item',
                                  value: itemTitle),
                              if (categoryName != null) ...[
                                const SizedBox(height: 4),
                                _InfoLine(
                                    icon: Icons.folder_outlined,
                                    label: 'Category',
                                    value: categoryName!),
                              ],
                              if (location != null &&
                                  location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _InfoLine(
                                    icon: Icons.location_on_outlined,
                                    label: 'Location',
                                    value: location),
                              ],
                              const SizedBox(height: 4),
                              _InfoLine(
                                  icon: Icons.person_outline_rounded,
                                  label: 'Claimant',
                                  value: claimantName),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Claim Details ──────────────────────────────
                    if (claimDetails.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      const SizedBox(height: 14),
                      Text(
                        'Claim Details',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.55)),
                      ),
                      const SizedBox(height: 6),
                      Text(claimDetails,
                          style: const TextStyle(fontSize: 14)),
                    ],

                    const SizedBox(height: 14),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 14),

                    // ── Admin Notes ────────────────────────────────
                    if (isPending) ...[
                      Text(
                        'Admin Notes',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.55)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Optional note (saved with decision)...',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                          hintStyle: TextStyle(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                              fontSize: 13),
                        ),
                      ),
                    ] else if (adminNotes.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 14,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 6),
                          Text(
                            'Admin Note: ',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55)),
                          ),
                          Expanded(
                            child: Text(adminNotes,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.7))),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Action Buttons ─────────────────────────────
                    if (isProcessingStatus)
                      const Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (onApprove != null)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Approve'),
                              onPressed: onApprove,
                            ),
                          if (onReject != null)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Reject'),
                              onPressed: onReject,
                            ),
                          if (onMarkPending != null)
                            OutlinedButton.icon(
                              icon: const Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 16),
                              label: const Text('Revert to Pending'),
                              onPressed: onMarkPending,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ThumbPlaceholder extends StatelessWidget {
  final bool isDark;
  const _ThumbPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      height: 64,
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : const Color(0xFFE8E8F0),
      child: Icon(Icons.image_outlined,
          size: 24, color: colorScheme.outline.withValues(alpha: 0.4)),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoLine(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: colorScheme.outline),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(fontSize: 13, color: colorScheme.outline)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              size: 12, color: Colors.orange),
          const SizedBox(width: 4),
          Text('$count pending',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = color ?? colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor
                : colorScheme.outline.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? activeColor
                : colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final dynamic selectedId;
  final ValueChanged<dynamic> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedId != null;
    final activeColor = colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? activeColor
              : colorScheme.outline.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: DropdownButton<dynamic>(
        value: selectedId,
        underline: const SizedBox(),
        isDense: true,
        hint: Text(
          'All Categories',
          style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? activeColor
              : colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        items: [
          DropdownMenuItem<dynamic>(
            value: null,
            child: Text('All Categories',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          ...categories.map((c) => DropdownMenuItem<dynamic>(
                value: c['id'],
                child: Text(c['name'] as String, style: const TextStyle(fontSize: 12)),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
