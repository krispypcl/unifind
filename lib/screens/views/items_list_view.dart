import 'package:flutter/material.dart';
import '../../main.dart';
import 'item_details_view.dart';

Future<void> _confirmDelete(
    BuildContext context, Map<String, dynamic> item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Item'),
      content: Text(
          'Are you sure you want to delete "${item['title'] ?? 'this item'}"? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    try {
      await supabase.from('items').delete().eq('id', item['id']);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }
}

class ItemsListView extends StatefulWidget {
  const ItemsListView({super.key});

  @override
  State<ItemsListView> createState() => _ItemsListViewState();
}

class _ItemsListViewState extends State<ItemsListView> {
  String? _typeFilter;
  String? _statusFilter;

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    return items.where((i) {
      final matchesType = _typeFilter == null || i['type'] == _typeFilter;
      final matchesStatus =
          _statusFilter == null || i['status'] == _statusFilter;
      return matchesType && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.list_alt_rounded, color: colorScheme.primary, size: 26),
            const SizedBox(width: 10),
            Text(
              'All Items',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Filter chips ──────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text('Type:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'All',
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null)),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Lost',
                  selected: _typeFilter == 'lost',
                  color: Colors.red,
                  onTap: () => setState(() => _typeFilter = 'lost')),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Found',
                  selected: _typeFilter == 'found',
                  color: Colors.green,
                  onTap: () => setState(() => _typeFilter = 'found')),
              const SizedBox(width: 20),
              Container(width: 1, height: 20, color: colorScheme.outlineVariant),
              const SizedBox(width: 20),
              Text('Status:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'All',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null)),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Open',
                  selected: _statusFilter == 'open',
                  color: Colors.blue,
                  onTap: () => setState(() => _statusFilter = 'open')),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Claimed',
                  selected: _statusFilter == 'claimed',
                  color: Colors.orange,
                  onTap: () => setState(() => _statusFilter = 'claimed')),
              const SizedBox(width: 6),
              _FilterChip(
                  label: 'Closed',
                  selected: _statusFilter == 'closed',
                  color: Colors.blueGrey,
                  onTap: () => setState(() => _statusFilter = 'closed')),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Grid ─────────────────────────────────────────────
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('items').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = _applyFilters(snapshot.data!);

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 52,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            _typeFilter == null && _statusFilter == null
                                ? 'No items found.'
                                : 'No items match the current filters.',
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                          if (_typeFilter != null || _statusFilter != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              icon: const Icon(Icons.filter_alt_off_outlined,
                                  size: 16),
                              label: const Text('Clear filters'),
                              onPressed: () => setState(() {
                                _typeFilter = null;
                                _statusFilter = null;
                              }),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900
                          ? 3
                          : constraints.maxWidth > 550
                              ? 2
                              : 1;
                      return GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _ItemGridCard(item: items[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Grid Card ─────────────────────────────────────────────────────────────────

class _ItemGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLost = item['type'] == 'lost';
    final String status = item['status'] as String? ?? '';
    final String? imageUrl = item['image_url'] as String?;
    final Color typeColor = isLost ? Colors.red : Colors.green;
    final Color statusColor = switch (status) {
      'open' => Colors.blue,
      'claimed' => Colors.orange,
      'closed' => Colors.blueGrey,
      _ => colorScheme.outline,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailsView(item: item)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image section ──────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _GridImagePlaceholder(isDark: isDark),
                        )
                      : _GridImagePlaceholder(isDark: isDark),
                  // Type + Status badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SmallBadge(
                            label: (item['type'] as String? ?? '')
                                .toUpperCase(),
                            color: typeColor),
                        const SizedBox(height: 4),
                        _SmallBadge(
                            label: status.toUpperCase(), color: statusColor),
                      ],
                    ),
                  ),
                  // Delete button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _confirmDelete(context, item),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content section ───────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String? ?? 'No Title',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((item['description'] as String?)
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 4),
                      Text(
                        item['description'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if ((item['location'] as String?)?.isNotEmpty == true)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.45)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              item['location'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5)),
                            ),
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

class _GridImagePlaceholder extends StatelessWidget {
  final bool isDark;
  const _GridImagePlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : const Color(0xFFE8E8F0),
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 36,
            color: colorScheme.outline.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
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
          color:
              selected ? activeColor.withValues(alpha: 0.14) : Colors.transparent,
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

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}
