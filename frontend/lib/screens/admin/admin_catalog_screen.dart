import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../core/localization.dart';

class AdminCatalogScreen extends StatelessWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('Catalog'),
          bottom: TabBar(
            labelColor: AppColors.green,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.green,
            tabs: [
              Tab(text: context.tr('Products')),
              Tab(text: context.tr('Categories')),
            ],
          ),
        ),
        body: const SafeArea(
          child: PageWidth(
            maxWidth: 1000,
            child: TabBarView(
              children: [
                _ProductsTab(),
                _CategoriesTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  const _ProductsTab();

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient.instance;
  List<Product> _products = const [];
  List<Category> _categories = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _busyId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _products.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.get('/admin/products', query: {'size': 100}),
        _api.get('/admin/categories'),
      ]);
      if (!mounted) return;
      final page = Map<String, dynamic>.from(results[0] as Map);
      final content = page['content'] is List ? page['content'] as List : const [];
      setState(() {
        _products = content
            .whereType<Map>()
            .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _categories = (results[1] as List<dynamic>)
            .whereType<Map>()
            .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) return _products;
    return _products
        .where(
          (product) =>
              product.name.toLowerCase().contains(term) ||
              (product.brand ?? '').toLowerCase().contains(term) ||
              product.categoryName.toLowerCase().contains(term),
        )
        .toList();
  }

  Future<void> _openForm({Product? existing}) async {
    if (_categories.isEmpty) {
      showMessage(
        context,
        'Create a category before adding products.',
        error: true,
      );
      return;
    }
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?.name ?? '');
    final brand = TextEditingController(text: existing?.brand ?? '');
    final unit = TextEditingController(text: existing?.unit ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    final formKey = GlobalKey<FormState>();
    int? categoryId = existing?.categoryId ??
        _categories
            .where((category) => category.active)
            .map((category) => category.id)
            .firstOrNull;
    bool active = existing?.active ?? true;
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText(isEdit ? 'Edit product' : 'New product'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: tr(context, 'Product name')),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter a product name'
                          : null,
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: brand,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(labelText: tr(context, 'Brand')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: unit,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Unit / pack size'),
                              hintText: tr(context, '1 kg, 500 g…'),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Enter a unit'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<int>(
                      initialValue: categoryId,
                      decoration: InputDecoration(labelText: tr(context, 'Category')),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: AppText(
                                category.active
                                    ? category.name
                                    : '${category.name} (inactive)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => categoryId = value),
                      validator: (value) =>
                          value == null ? 'Choose a category' : null,
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: imageUrl,
                      decoration: InputDecoration(labelText: tr(context, 'Image URL')),
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: tr(context, 'Description')),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppColors.green,
                      title: const AppText(
                        'Active in catalog',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const AppText(
                        'Inactive products disappear from customer search.',
                        style: TextStyle(fontSize: 10.5),
                      ),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        final body = {
                          'name': name.text.trim(),
                          'brand': _nullIfBlank(brand.text),
                          'description': _nullIfBlank(description.text),
                          'imageUrl': _nullIfBlank(imageUrl.text),
                          'unit': unit.text.trim(),
                          'categoryId': categoryId,
                          'active': active,
                        };
                        if (isEdit) {
                          await _api.put('/admin/products/${existing.id}', body: body);
                        } else {
                          await _api.post('/admin/products', body: body);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (mounted) {
                          showMessage(
                            context,
                            isEdit ? 'Product updated.' : 'Product created.',
                          );
                          await _load();
                        }
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          showMessage(context, error.message, error: true);
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : AppText(isEdit ? 'Save changes' : 'Create product'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    brand.dispose();
    unit.dispose();
    description.dispose();
    imageUrl.dispose();
  }

  Future<void> _deactivate(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Deactivate product?'),
        content: AppText(
          '${product.name} will be hidden from the customer catalog. Shops already listing it will keep their inventory records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Deactivate', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = product.id);
    try {
      await _api.delete('/admin/products/${product.id}');
      if (!mounted) return;
      showMessage(context, 'Product deactivated.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const AppText('New product'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingView(message: 'Loading catalog…')
            : _error != null
                ? ListView(
                    children: [
                      SizedBox(
                        height: 450,
                        child: ErrorRetry(message: _error!, onRetry: _load),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 92),
                    children: [
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: tr(context, 'Search products, brands or categories…'),
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 13),
                      AppText(
                        '${filtered.length} of ${_products.length} products',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      const SizedBox(height: 9),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products found',
                            message: 'Create a product or try a different search.',
                          ),
                        )
                      else
                        ...filtered.map(
                          (product) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _productCard(product),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _productCard(Product product) {
    final busy = _busyId == product.id;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AppImage(url: product.imageUrl, width: 58, height: 58, radius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusPill(status: product.active ? 'ACTIVE' : 'INACTIVE'),
                  ],
                ),
                const SizedBox(height: 2),
                AppText(
                  '${product.brand ?? 'Unbranded'} · ${product.unit} · ${product.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                AppText(
                  '${product.availableShops} shop${product.availableShops == 1 ? '' : 's'} · ${product.totalStock} in stock'
                  '${product.bestPrice == null ? '' : ' · from ${rupee(product.bestPrice!)}'}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              tooltip: context.tr('Edit product'),
              onPressed: () => _openForm(existing: product),
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
            IconButton(
              tooltip: context.tr('Deactivate product'),
              onPressed: product.active ? () => _deactivate(product) : null,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: AppColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient.instance;
  List<Category> _categories = const [];
  bool _loading = true;
  String? _error;
  int? _busyId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _categories.isEmpty;
      _error = null;
    });
    try {
      final data = await _api.get('/admin/categories') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _categories = data
            .whereType<Map>()
            .map((item) => Category.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Category? existing}) async {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    final displayOrder =
        TextEditingController(text: '${existing?.displayOrder ?? 0}');
    final formKey = GlobalKey<FormState>();
    bool active = existing?.active ?? true;
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText(isEdit ? 'Edit category' : 'New category'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: tr(context, 'Category name')),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter a category name'
                          : null,
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: tr(context, 'Description')),
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: imageUrl,
                      decoration: InputDecoration(labelText: tr(context, 'Image URL')),
                    ),
                    const SizedBox(height: 11),
                    TextFormField(
                      controller: displayOrder,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Display order'),
                        helperText: tr(context, 'Lower numbers appear first.'),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return AppLocalizations.current.tr('Enter 0 or more');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppColors.green,
                      title: const AppText(
                        'Active category',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        final body = {
                          'name': name.text.trim(),
                          'description': _nullIfBlank(description.text),
                          'imageUrl': _nullIfBlank(imageUrl.text),
                          'active': active,
                          'displayOrder': int.parse(displayOrder.text.trim()),
                        };
                        if (isEdit) {
                          await _api.put(
                            '/admin/categories/${existing.id}',
                            body: body,
                          );
                        } else {
                          await _api.post('/admin/categories', body: body);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (mounted) {
                          showMessage(
                            context,
                            isEdit ? 'Category updated.' : 'Category created.',
                          );
                          await _load();
                        }
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          showMessage(context, error.message, error: true);
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : AppText(isEdit ? 'Save changes' : 'Create category'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    imageUrl.dispose();
    displayOrder.dispose();
  }

  Future<void> _deactivate(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Deactivate category?'),
        content: AppText(
          '${category.name} will be hidden from the customer catalog. Products in it stay in the database and can be reactivated later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Deactivate', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = category.id);
    try {
      await _api.delete('/admin/categories/${category.id}');
      if (!mounted) return;
      showMessage(context, 'Category deactivated.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const AppText('New category'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingView(message: 'Loading categories…')
            : _error != null
                ? ListView(
                    children: [
                      SizedBox(
                        height: 450,
                        child: ErrorRetry(message: _error!, onRetry: _load),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 92),
                    children: [
                      if (_categories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: EmptyState(
                            icon: Icons.category_outlined,
                            title: 'No categories yet',
                            message:
                                'Create your first category to start building the catalog.',
                          ),
                        )
                      else
                        ..._categories.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _categoryCard(category),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _categoryCard(Category category) {
    final busy = _busyId == category.id;
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          AppImage(
            url: category.imageUrl,
            width: 50,
            height: 50,
            radius: 12,
            icon: Icons.category_rounded,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusPill(status: category.active ? 'ACTIVE' : 'INACTIVE'),
                  ],
                ),
                const SizedBox(height: 2),
                AppText(
                  category.description ?? 'No description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                AppText(
                  'Display order ${category.displayOrder} · ID #${category.id}',
                  style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              tooltip: context.tr('Edit category'),
              onPressed: () => _openForm(existing: category),
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
            IconButton(
              tooltip: context.tr('Deactivate category'),
              onPressed: category.active ? () => _deactivate(category) : null,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: AppColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
