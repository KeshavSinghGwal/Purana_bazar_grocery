import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final ApiClient _api = ApiClient.instance;
  List<AdminCustomer> _customers = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _customers.isEmpty;
      _error = null;
    });
    try {
      final data = await _api.get('/admin/customers') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _customers = data
            .whereType<Map>()
            .map((item) => AdminCustomer.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminCustomer> get _filtered {
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) return _customers;
    return _customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(term) ||
              customer.email.toLowerCase().contains(term) ||
              (customer.phone ?? '').contains(term),
        )
        .toList();
  }

  Future<void> _toggle(AdminCustomer customer) async {
    final suspend = customer.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspend ? 'Suspend customer?' : 'Reactivate customer?'),
        content: Text(
          suspend
              ? '${customer.name} will no longer be able to sign in or place orders. Existing orders are not affected.'
              : '${customer.name} will be able to sign in and order again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              suspend ? 'Suspend' : 'Reactivate',
              style: TextStyle(color: suspend ? AppColors.red : AppColors.green),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = customer.id);
    try {
      await _api.put(
        '/admin/customers/${customer.id}/${suspend ? 'suspend' : 'reactivate'}',
      );
      if (!mounted) return;
      showMessage(context, suspend ? 'Customer suspended.' : 'Customer reactivated.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final active = _customers.where((customer) => customer.active).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 900,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const LoadingView(message: 'Loading customers…')
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
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _summary(
                                  'Registered',
                                  '${_customers.length}',
                                  AppColors.green,
                                  Icons.people_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _summary(
                                  'Active',
                                  '$active',
                                  const Color(0xFF1565C0),
                                  Icons.verified_user_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            onChanged: (value) => setState(() => _query = value),
                            decoration: const InputDecoration(
                              hintText: 'Search name, email or phone…',
                              prefixIcon: Icon(Icons.search_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 50),
                              child: EmptyState(
                                icon: Icons.people_outline_rounded,
                                title: 'No customers found',
                                message: 'Try a different search term.',
                              ),
                            )
                          else
                            ...filtered.map(
                              (customer) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: _customerCard(customer),
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
          const SizedBox(width: 9),
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

  Widget _customerCard(AdminCustomer customer) {
    final busy = _busyId == customer.id;
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: customer.active ? AppColors.mint : AppColors.border,
            child: Text(
              initials(customer.name),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: customer.active ? AppColors.green : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusPill(status: customer.active ? 'ACTIVE' : 'SUSPENDED'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  customer.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${customer.phone ?? 'No phone'} · ${customer.orderCount} order${customer.orderCount == 1 ? '' : 's'} · Joined ${fullDate(customer.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              tooltip: customer.active ? 'Suspend customer' : 'Reactivate customer',
              onPressed: () => _toggle(customer),
              icon: Icon(
                customer.active
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20,
                color: customer.active ? AppColors.red : AppColors.green,
              ),
            ),
        ],
      ),
    );
  }
}
