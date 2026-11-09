import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  final ApiClient _api = ApiClient.instance;
  List<InventoryItem> _inventory = const [];
  bool _loading = true;
  String? _error;
  bool _adding = false;
  int? _deletingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _inventory.isEmpty;
      _error = null;
    });
    try {
      final data = await _api.get('/shop-owner/inventory') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _inventory = data
            .whereType<Map>()
            .map((item) => InventoryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startAdd() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final data = await _api.get('/shop-owner/products/available') as List<dynamic>;
      final products = data
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      if (products.isEmpty) {
        showMessage(
          context,
          'Every active catalog product is already listed for your shop.',
          error: true,
        );
        return;
      }
      final product = await _pickProduct(products);
      if (product != null && mounted) {
        await _openForm(product: product);
      }
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<Product?> _pickProduct(List<Product> products) {
    String query = '';
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = products.where((product) {
            final text = query.toLowerCase();
            return product.name.toLowerCase().contains(text) ||
                (product.brand ?? '').toLowerCase().contains(text);
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.76,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add a catalog product',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose a product, then set your shop price and stock.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) => setSheetState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Search catalog products…',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matching product',
                          message: 'Try another name or brand.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 5),
                              leading: AppImage(
                                url: product.imageUrl,
                                width: 46,
                                height: 46,
                                radius: 9,
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${product.unit} · ${product.categoryName}',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              trailing: const Icon(Icons.add_circle_outline_rounded,
                                  color: AppColors.green),
                              onTap: () => Navigator.pop(context, product),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm({Product? product, InventoryItem? existing}) {
    final isEdit = existing != null;
    final price = TextEditingController(
      text: isEdit ? existing.price.toStringAsFixed(2) : '',
    );
    final quantity = TextEditingController(
      text: isEdit ? '${existing.availableQuantity}' : '0',
    );
    bool active = isEdit ? existing.active : true;
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit listing' : 'Add listing'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? existing.productName : product!.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Selling price (₹)',
                      prefixText: '₹ ',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed < 0.01) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Available quantity'),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed < 0 || parsed > 100000) {
                        return 'Enter 0–100000';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppColors.green,
                    title: const Text(
                      'Listing active',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        final body = {
                          'productId': isEdit ? existing.productId : product!.id,
                          'price': double.parse(price.text.trim()),
                          'availableQuantity': int.parse(quantity.text.trim()),
                          'active': active,
                        };
                        if (isEdit) {
                          await _api.put('/shop-owner/inventory/${existing.id}', body: body);
                        } else {
                          await _api.post('/shop-owner/inventory', body: body);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (mounted) {
                          showMessage(
                            context,
                            isEdit ? 'Listing updated.' : 'Product added to your shop.',
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
                  : Text(isEdit ? 'Save changes' : 'Add listing'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      price.dispose();
      quantity.dispose();
    });
  }

  Future<void> _delete(InventoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text(
          '${item.productName} will be hidden from customers and its stock will be set to zero. Existing orders are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deletingId = item.id);
    try {
      await _api.delete('/shop-owner/inventory/${item.id}');
      if (!mounted) return;
      showMessage(context, 'Listing removed.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _inventory.where((item) => item.active).length;
    final lowStock = _inventory
        .where((item) => item.active && item.availableQuantity <= 5)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop inventory'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _startAdd,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: _adding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('Add listing'),
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 900,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const LoadingView(message: 'Loading inventory…')
                : _error != null
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 470,
                            child: ErrorRetry(message: _error!, onRetry: _load),
                          ),
                        ],
                      )
                    : _inventory.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'Your shelves are empty',
                                message:
                                    'Add catalog products with your own price and stock. Customers will see this live inventory.',
                                actionLabel: 'Add your first listing',
                                onAction: _startAdd,
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _summary(
                                      'Active listings',
                                      '$active',
                                      AppColors.green,
                                      Icons.inventory_2_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _summary(
                                      'Low / out of stock',
                                      '$lowStock',
                                      AppColors.orange,
                                      Icons.warning_amber_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              ..._inventory.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _inventoryCard(item),
                                ),
                              ),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _summary(String label, String value, Color color, IconData icon) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inventoryCard(InventoryItem item) {
    final deleting = _deletingId == item.id;
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(url: item.imageUrl, width: 66, height: 66, radius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusPill(status: item.active ? 'ACTIVE' : 'INACTIVE'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.unit} · ${item.categoryName}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      rupee(item.price),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.availableQuantity == 0
                            ? AppColors.red.withValues(alpha: 0.07)
                            : item.availableQuantity <= 5
                                ? AppColors.orange.withValues(alpha: 0.09)
                                : AppColors.paleMint,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        item.availableQuantity == 0
                            ? 'Out of stock'
                            : '${item.availableQuantity} in stock',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: item.availableQuantity == 0
                              ? AppColors.red
                              : item.availableQuantity <= 5
                                  ? AppColors.orange
                                  : AppColors.green,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openForm(existing: item),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: deleting ? null : () => _delete(item),
                      icon: deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded,
                              size: 19, color: AppColors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
