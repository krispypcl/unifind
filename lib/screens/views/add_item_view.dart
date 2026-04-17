import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class AddItemView extends StatefulWidget {
  const AddItemView({super.key});

  @override
  State<AddItemView> createState() => _AddItemViewState();
}

class _AddItemViewState extends State<AddItemView> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedType = 'lost';
  String _selectedStatus = 'open';
  int? _selectedCategoryId;

  List<Map<String, dynamic>> _categories = [];
  bool _categoriesLoading = true;

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await supabase
          .from('categories')
          .select('id, name')
          .order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _categoriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _imageBytes = bytes;
      });
    }
  }

  void _removeImage() => setState(() {
        _pickedImage = null;
        _imageBytes = null;
      });

  Future<String?> _uploadImage() async {
    if (_pickedImage == null || _imageBytes == null) return null;
    final userId = supabase.auth.currentUser!.id;
    final ext =
        _pickedImage!.name.contains('.') ? _pickedImage!.name.split('.').last : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('item-images').uploadBinary(
          path,
          _imageBytes!,
          fileOptions: FileOptions(
            contentType: _pickedImage!.mimeType ?? 'image/jpeg',
            upsert: true,
          ),
        );
    return supabase.storage.from('item-images').getPublicUrl(path);
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await _uploadImage();
      }
      await supabase.from('items').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'type': _selectedType,
        'status': _selectedStatus,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        'image_url': imageUrl,
        'user_id': userId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!')),
        );
        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        setState(() {
          _pickedImage = null;
          _imageBytes = null;
          _selectedType = 'lost';
          _selectedStatus = 'open';
          _selectedCategoryId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error adding item: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: colorScheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'Add New Item',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Image picker ────────────────────────
                        _ImagePickerSection(
                          imageBytes: _imageBytes,
                          isDark: isDark,
                          onPick: _pickImage,
                          onRemove: _removeImage,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                              labelText: 'Item Title',
                              border: OutlineInputBorder()),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                    labelText: 'Location',
                                    border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('cat_$_selectedCategoryId'),
                                initialValue: _selectedCategoryId,
                                decoration: const InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder()),
                                hint: _categoriesLoading
                                    ? const Text('Loading...')
                                    : const Text('Select category'),
                                items: _categories
                                    .map((c) => DropdownMenuItem<int>(
                                          value: c['id'] as int,
                                          child: Text(c['name'] as String),
                                        ))
                                    .toList(),
                                onChanged: _categoriesLoading
                                    ? null
                                    : (v) => setState(
                                        () => _selectedCategoryId = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('type_$_selectedType'),
                                initialValue: _selectedType,
                                decoration: const InputDecoration(
                                    labelText: 'Type',
                                    border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'lost', child: Text('Lost')),
                                  DropdownMenuItem(
                                      value: 'found', child: Text('Found')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedType = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('status_$_selectedStatus'),
                                initialValue: _selectedStatus,
                                decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'open', child: Text('Open')),
                                  DropdownMenuItem(
                                      value: 'claimed', child: Text('Claimed')),
                                  DropdownMenuItem(
                                      value: 'closed', child: Text('Closed')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedStatus = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        _isSubmitting
                            ? const Center(
                                child: CircularProgressIndicator())
                            : FilledButton.icon(
                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: const Text('Save Item'),
                                onPressed: _submitItem,
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Image Picker Section ──────────────────────────────────────────────────────

class _ImagePickerSection extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isDark;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerSection({
    required this.imageBytes,
    required this.isDark,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Item Photo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        if (imageBytes != null)
          // Preview with remove button
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  imageBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 14),
                  label: const Text('Change', style: TextStyle(fontSize: 12)),
                  onPressed: onPick,
                ),
              ),
            ],
          )
        else
          // Dashed picker box
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.4),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 40, color: colorScheme.primary.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  Text('Click to upload an image',
                      style: TextStyle(
                          color: colorScheme.primary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('PNG, JPG, WEBP supported',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
