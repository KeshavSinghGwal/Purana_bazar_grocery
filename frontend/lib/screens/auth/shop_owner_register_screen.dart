import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';
import '../../core/localization.dart';

class ShopOwnerRegisterScreen extends StatefulWidget {
  const ShopOwnerRegisterScreen({super.key});

  @override
  State<ShopOwnerRegisterScreen> createState() => _ShopOwnerRegisterScreenState();
}

class _ShopOwnerRegisterScreenState extends State<ShopOwnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _shopName = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _latitude = TextEditingController(text: '22.7533');
  final _longitude = TextEditingController(text: '75.8937');
  final _radius = TextEditingController(text: '5');
  final _shopPhone = TextEditingController();
  String _category = 'Kirana';
  TimeOfDay _opening = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _closing = const TimeOfDay(hour: 22, minute: 0);
  bool _obscure = true;
  bool _busy = false;

  static const _categories = [
    'Kirana',
    'Grocery',
    'Supermarket',
    'Fresh Produce',
    'Bakery',
    'Pharmacy',
    'Other',
  ];

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _password,
      _shopName,
      _description,
      _address,
      _latitude,
      _longitude,
      _radius,
      _shopPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _timeValue(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  String _timeLabel(TimeOfDay time) => time.format(context);

  Future<void> _pickTime(bool opening) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: opening ? _opening : _closing,
    );
    if (picked != null) {
      setState(() {
        if (opening) {
          _opening = picked;
        } else {
          _closing = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().registerShopOwner({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'shopName': _shopName.text.trim(),
        'description': _description.text.trim(),
        'address': _address.text.trim(),
        'latitude': double.parse(_latitude.text.trim()),
        'longitude': double.parse(_longitude.text.trim()),
        'openingTime': _timeValue(_opening),
        'closingTime': _timeValue(_closing),
        'deliveryRadius': double.parse(_radius.text.trim()),
        'shopCategory': _category,
        'shopPhone': _shopPhone.text.trim().isEmpty ? null : _shopPhone.text.trim(),
      });
      if (!mounted) return;
      showMessage(
        context,
        'Shop submitted for approval. You can prepare inventory while you wait.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not register your shop.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Register your shop')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.greenGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'Partner with Purana Bazaar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 5),
                                AppText(
                                  'New shops go live after an administrator checks your details. You can set up inventory right away.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'Owner account'),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(labelText: tr(context, 'Your full name')),
                            validator: _required,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(labelText: tr(context, 'Email address')),
                            validator: (value) =>
                                value == null || !value.contains('@') ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(labelText: tr(context, 'Phone number')),
                            validator: _required,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Password'),
                              helperText: tr(context, 'At least 8 characters'),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                              ),
                            ),
                            validator: (value) => value == null || value.length < 8
                                ? 'Use at least 8 characters'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'Shop details'),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _shopName,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(labelText: tr(context, 'Shop name')),
                            validator: _required,
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _description,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Short description'),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _address,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Full shop address'),
                              alignLabelWithHint: true,
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 13),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: InputDecoration(labelText: tr(context, 'Shop category')),
                            items: _categories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: AppText(category),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _category = value);
                            },
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _shopPhone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Shop phone (optional)'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'Location & hours'),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latitude,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(labelText: tr(context, 'Latitude')),
                                  validator: (value) => double.tryParse(value ?? '') == null
                                      ? 'Enter a valid latitude'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _longitude,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(labelText: tr(context, 'Longitude')),
                                  validator: (value) => double.tryParse(value ?? '') == null
                                      ? 'Enter a valid longitude'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _radius,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: tr(context, 'Delivery radius (km)'),
                              helperText: tr(context, 'Minimum 0.5 km, maximum 50 km'),
                            ),
                            validator: (value) {
                              final radius = double.tryParse(value ?? '');
                              if (radius == null || radius < 0.5 || radius > 50) {
                                return AppLocalizations.current.tr('Enter a radius between 0.5 and 50');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: _timeField(
                                  context,
                                  label: 'Opens at',
                                  value: _timeLabel(_opening),
                                  onTap: () => _pickTime(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _timeField(
                                  context,
                                  label: 'Closes at',
                                  value: _timeLabel(_closing),
                                  onTap: () => _pickTime(false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const AppText('Submit shop for approval'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: AppText(
                        'Your shop will remain hidden from customers until approved.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => AppText(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      );

  Widget _timeField(BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr(context, label),
          suffixIcon: const Icon(Icons.schedule_rounded, size: 20),
        ),
        child: AppText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
}
