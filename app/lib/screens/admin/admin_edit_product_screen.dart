import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/admin/product_admin_service.dart';
import '../../application/providers.dart';
import '../../data/services/image_upload_service.dart';
import '../../domain/entities/product.dart';
import '../../presentation/widgets/product_image.dart';
import '../../theme/app_colors.dart';

/// Sentinel dropdown value that switches the category field to a text input.
const _kNewCategory = '__new__';

/// Add a new product (when [product] is null) or edit an existing one.
class AdminEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;

  const AdminEditProductScreen({super.key, this.product});

  @override
  ConsumerState<AdminEditProductScreen> createState() =>
      _AdminEditProductScreenState();
}

class _AdminEditProductScreenState
    extends ConsumerState<AdminEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _emoji;
  late final TextEditingController _stepInGrams;
  final _newCategory = TextEditingController();

  late String _category;
  bool _newCategoryMode = false;
  late bool _inStock;
  late bool _isLoose;
  late bool _hasVariants;
  String? _imagePath;
  bool _isSaving = false;
  final List<_VariantDraft> _variants = [];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _unit = TextEditingController(text: p?.unit ?? '');
    _price = TextEditingController(text: p != null ? '${p.price}' : '');
    _emoji = TextEditingController(text: p?.emoji ?? '🛒');
    _stepInGrams = TextEditingController(
      text: p != null ? '${p.stepInGrams}' : '250',
    );
    _category = p?.category ?? '';
    _inStock = p?.inStock ?? true;
    _isLoose = p?.isLoose ?? false;
    _hasVariants = false;
    _imagePath = p?.imagePath;
    _loadVariants();
  }

  void _loadVariants() {
    if (!_isEditing) return;
    final all = ref.read(productsProvider).value ?? const [];
    final children = all.where((p) => p.parentProductId == widget.product!.id);
    _hasVariants = children.isNotEmpty;
    _variants.addAll(
      children.map(
        (p) => _VariantDraft(
          existing: p,
          name: TextEditingController(text: p.name),
          unit: TextEditingController(text: p.unit),
          price: TextEditingController(text: '${p.price}'),
          step: TextEditingController(text: '${p.stepInGrams}'),
          isLoose: p.isLoose,
          inStock: p.inStock,
          isVisible: p.isVisible,
          imagePath: p.imagePath,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    _emoji.dispose();
    _stepInGrams.dispose();
    _newCategory.dispose();
    for (final v in _variants) {
      v.name.dispose();
      v.unit.dispose();
      v.price.dispose();
      v.step.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVariantImage(_VariantDraft draft) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (!mounted || source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => draft.imagePath = picked.path);
  }

  List<String> _existingCategories() =>
      ref.read(categoriesProvider).where((c) => c != 'All').toList();

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (!mounted || source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _imagePath = picked.path);
  }

  void _removePhoto() => setState(() => _imagePath = null);

  /// Uploads a freshly picked local image to Firebase Storage and returns its
  /// download URL. Values that are already URLs (unchanged existing photos) or
  /// null are returned as-is so we never re-upload.
  Future<String?> _resolveImageUrl(String? path, String productId) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final uploader = ref.read(imageUploadServiceProvider);
    return uploader.uploadProductImage(productId, XFile(path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final category = _newCategoryMode
        ? _newCategory.text.trim()
        : _category.trim();
    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose or enter a category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _persist(category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Product updated' : 'Product added'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save product: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _persist(String category) async {
    final service = ref.read(productAdminServiceProvider);
    final emoji = _emoji.text.trim().isEmpty ? '🛒' : _emoji.text.trim();

    final parentId = _isEditing
        ? widget.product!.id
        : 'p${DateTime.now().microsecondsSinceEpoch}';
    final parentImageUrl = await _resolveImageUrl(_imagePath, parentId);

    final parent = Product(
      id: parentId,
      name: _name.text.trim(),
      unit: _hasVariants ? '' : _unit.text.trim(),
      category: category,
      price: _hasVariants ? 0 : int.parse(_price.text),
      emoji: emoji,
      inStock: _hasVariants ? true : _inStock,
      imagePath: parentImageUrl,
      isLoose: _hasVariants ? false : _isLoose,
      stepInGrams: _hasVariants
          ? 250
          : (int.tryParse(_stepInGrams.text) ?? 250),
    );

    if (_isEditing) {
      await service.update(parent);
    } else {
      await service.add(parent);
    }

    if (_hasVariants) {
      for (final draft in _variants) {
        final variantId =
            draft.existing?.id ??
            'p${DateTime.now().microsecondsSinceEpoch}${draft.hashCode}';
        final variantImageUrl = await _resolveImageUrl(
          draft.imagePath,
          variantId,
        );
        final variant = Product(
          id: variantId,
          name: draft.name.text.trim(),
          unit: draft.unit.text.trim(),
          category: '',
          price: int.parse(draft.price.text),
          emoji: '',
          inStock: draft.inStock,
          imagePath: variantImageUrl,
          isLoose: draft.isLoose,
          stepInGrams: int.tryParse(draft.step.text) ?? 250,
          parentProductId: parent.id,
          isVisible: draft.isVisible,
        );
        if (draft.existing != null) {
          await service.update(variant);
        } else {
          await service.add(variant);
        }
      }

      // Delete removed variants.
      if (_isEditing) {
        final all = ref.read(productsProvider).value ?? const [];
        final existingIds = _variants
            .where((v) => v.existing != null)
            .map((v) => v.existing!.id)
            .toSet();
        for (final old in all.where((p) => p.parentProductId == parent.id)) {
          if (!existingIds.contains(old.id)) {
            await service.delete(old.id);
          }
        }
      }
    } else if (_isEditing) {
      // If variants were removed, delete all children.
      final all = ref.read(productsProvider).value ?? const [];
      for (final old in all.where((p) => p.parentProductId == parent.id)) {
        await service.delete(old.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existingCategories();
    // Keep a valid dropdown selection when not adding a new category.
    if (!_newCategoryMode && !existing.contains(_category)) {
      _category = existing.isNotEmpty ? existing.first : '';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: _photoPicker()),
            const SizedBox(height: 18),
            _field(
              controller: _name,
              label: 'NAME',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_hasVariants)
                  Expanded(
                    child: _field(controller: _unit, label: 'UNIT (e.g. 1 kg)'),
                  ),
                if (!_hasVariants) const SizedBox(width: 12),
                Expanded(child: _categoryField(existing)),
              ],
            ),
            if (!_hasVariants) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _price,
                      label: 'PRICE (₹)',
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter a valid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _emoji,
                      label: 'ICON (used if no photo)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _stockToggle(),
              const SizedBox(height: 14),
              _looseToggle(),
              if (_isLoose) ...[
                const SizedBox(height: 12),
                _field(
                  controller: _stepInGrams,
                  label: 'STEP SIZE (grams, e.g. 250)',
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a step size';
                    return null;
                  },
                ),
              ],
            ],
            if (_hasVariants) ...[
              const SizedBox(height: 6),
              const Text(
                'Product details like unit, price and stock are now managed inside each variant below.',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 14),
            _variantsToggle(),
            if (_hasVariants) ...[
              const SizedBox(height: 12),
              _VariantsEditor(
                variants: _variants,
                onChanged: () => setState(() {}),
                onPickImage: _pickVariantImage,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPicker() {
    final path = _imagePath;
    final hasPhoto =
        path != null && (path.startsWith('http') || File(path).existsSync());
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 110,
            height: 110,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: hasPhoto
                ? ProductImage(
                    imagePath: path,
                    emoji: _emoji.text.isEmpty ? '🛒' : _emoji.text,
                    emojiSize: 40,
                    width: 110,
                    height: 110,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _emoji.text.isEmpty ? '🛒' : _emoji.text,
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.add_a_photo_outlined,
                        size: 18,
                        color: AppColors.saffronDark,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: hasPhoto ? _removePhoto : _pickImage,
          icon: Icon(
            hasPhoto ? Icons.delete_outline : Icons.upload_outlined,
            size: 16,
          ),
          label: Text(hasPhoto ? 'Remove photo' : 'Upload photo'),
        ),
      ],
    );
  }

  Widget _categoryField(List<String> existing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: _newCategoryMode ? _kNewCategory : _category,
          isExpanded: true,
          items: [
            for (final c in existing)
              DropdownMenuItem(value: c, child: Text(c)),
            const DropdownMenuItem(
              value: _kNewCategory,
              child: Text('➕ New category'),
            ),
          ],
          onChanged: (v) {
            setState(() {
              if (v == _kNewCategory) {
                _newCategoryMode = true;
              } else {
                _newCategoryMode = false;
                _category = v ?? _category;
              }
            });
          },
        ),
        if (_newCategoryMode) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _newCategory,
            decoration: const InputDecoration(hintText: 'New category name'),
            validator: (v) =>
                _newCategoryMode && (v == null || v.trim().isEmpty)
                ? 'Enter category'
                : null,
          ),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _stockToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Text(
            'In Stock',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Switch(
            value: _inStock,
            activeThumbColor: AppColors.green,
            onChanged: (v) => setState(() => _inStock = v),
          ),
        ],
      ),
    );
  }

  Widget _looseToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loose Item',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Price is per kg. Customer can order in steps.',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: _isLoose,
            activeThumbColor: AppColors.saffron,
            onChanged: (v) => setState(() => _isLoose = v),
          ),
        ],
      ),
    );
  }

  Widget _variantsToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Has Variants',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Add options like loose, bag, bottle etc.',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: _hasVariants,
            activeThumbColor: AppColors.green,
            onChanged: (v) => setState(() {
              _hasVariants = v;
              if (v && _variants.isEmpty) {
                _variants.add(_VariantDraft.empty());
              }
            }),
          ),
        ],
      ),
    );
  }
}

class _VariantDraft {
  final Product? existing;
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController price;
  final TextEditingController step;
  bool isLoose;
  bool inStock;
  bool isVisible;
  String? imagePath;

  _VariantDraft({
    this.existing,
    required this.name,
    required this.unit,
    required this.price,
    required this.step,
    this.isLoose = false,
    this.inStock = true,
    this.isVisible = true,
    this.imagePath,
  });

  factory _VariantDraft.empty() => _VariantDraft(
    name: TextEditingController(),
    unit: TextEditingController(text: '1 kg'),
    price: TextEditingController(),
    step: TextEditingController(text: '250'),
  );

  bool get hasPhoto =>
      imagePath != null &&
      (imagePath!.startsWith('http') || File(imagePath!).existsSync());
}

class _VariantsEditor extends StatelessWidget {
  final List<_VariantDraft> variants;
  final VoidCallback onChanged;
  final void Function(_VariantDraft) onPickImage;

  const _VariantsEditor({
    required this.variants,
    required this.onChanged,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < variants.length; i++) ...[
          _VariantCard(
            index: i,
            draft: variants[i],
            onRemove: () {
              variants.removeAt(i);
              onChanged();
            },
            onChanged: onChanged,
            onPickImage: () => onPickImage(variants[i]),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () {
            variants.add(_VariantDraft.empty());
            onChanged();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Variant'),
        ),
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  final int index;
  final _VariantDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onPickImage;

  const _VariantCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onChanged,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variant ${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              _switch('Visible', draft.isVisible, (v) {
                draft.isVisible = v;
                onChanged();
              }),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: const Color(0xFFC62828),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onPickImage,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  alignment: Alignment.center,
                  child: draft.hasPhoto
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ProductImage(
                            imagePath: draft.imagePath,
                            emoji: '🛒',
                            emojiSize: 22,
                            width: 56,
                            height: 56,
                          ),
                        )
                      : const Icon(
                          Icons.add_a_photo_outlined,
                          size: 22,
                          color: AppColors.saffronDark,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _VariantField(
                      controller: draft.name,
                      label: 'VARIANT NAME (optional)',
                      hint: 'e.g. Company X',
                    ),
                    const SizedBox(height: 8),
                    _VariantField(
                      controller: draft.unit,
                      label: 'UNIT',
                      hint: 'e.g. 1 kg',
                    ),
                    const SizedBox(height: 8),
                    _VariantField(
                      controller: draft.price,
                      label: 'PRICE (₹)',
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _switch('Loose', draft.isLoose, (v) {
                draft.isLoose = v;
                onChanged();
              }),
              const SizedBox(width: 12),
              _switch('In Stock', draft.inStock, (v) {
                draft.inStock = v;
                onChanged();
              }),
              if (draft.isLoose) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _VariantField(
                    controller: draft.step,
                    label: 'STEP (g)',
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Switch(
          value: value,
          activeThumbColor: AppColors.saffron,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _VariantField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  const _VariantField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          },
        ),
      ],
    );
  }
}
