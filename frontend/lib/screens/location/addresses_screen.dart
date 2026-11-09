import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/location_provider.dart';
import '../../widgets/common.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LocationProvider>();
      if (provider.addresses.isEmpty && !provider.loading) {
        provider.load();
      }
    });
  }

  Future<void> _openForm({Address? address}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressFormScreen(address: address)),
    );
    if (result == true && mounted && widget.selectionMode) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete(Address address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label} from your saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<LocationProvider>().deleteAddress(address.id);
      if (mounted) showMessage(context, 'Address removed.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  Future<void> _makeDefault(Address address) async {
    try {
      await context.read<LocationProvider>().makeDefault(address.id);
      if (mounted) showMessage(context, 'Default address updated.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Choose delivery address' : 'Saved addresses'),
        actions: [
          IconButton(
            tooltip: 'Add address',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: PageWidth(
          maxWidth: 760,
          child: RefreshIndicator(
            onRefresh: location.load,
            child: location.loading && location.addresses.isEmpty
                ? const LoadingView(message: 'Loading your addresses…')
                : location.error != null && location.addresses.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 480,
                            child: ErrorRetry(
                              message: location.error!,
                              onRetry: location.load,
                            ),
                          ),
                        ],
                      )
                    : location.addresses.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const SizedBox(height: 60),
                              EmptyState(
                                icon: Icons.location_on_outlined,
                                title: 'Where should we deliver?',
                                message:
                                    'Add your home, office or any other address to see nearby shops and delivery times.',
                                actionLabel: 'Add your first address',
                                onAction: () => _openForm(),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.mint,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.near_me_outlined,
                                        color: AppColors.green, size: 22),
                                    SizedBox(width: 11),
                                    Expanded(
                                      child: Text(
                                        'We use your address to find eligible shops and calculate the nearest-shop delivery.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.45,
                                          color: AppColors.darkGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...location.addresses.map(
                                (address) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _addressCard(address, location),
                                ),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => _openForm(),
                                icon: const Icon(Icons.add_location_alt_outlined),
                                label: const Text('Add another address'),
                              ),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _addressCard(Address address, LocationProvider location) {
    final selected = location.selected?.id == address.id;
    return AppCard(
      padding: const EdgeInsets.all(15),
      borderColor: selected ? AppColors.green : AppColors.border,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          location.select(address);
          if (widget.selectionMode) Navigator.of(context).pop(true);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.mint : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                address.label.toLowerCase().contains('office')
                    ? Icons.apartment_rounded
                    : Icons.home_rounded,
                color: selected ? AppColors.green : AppColors.muted,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.green,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address.formattedAddress,
                    style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!address.isDefault)
                        TextButton(
                          onPressed: () => _makeDefault(address),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 26),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Set as default',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Edit',
                        onPressed: () => _openForm(address: address),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete',
                        onPressed: () => _delete(address),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Icon(Icons.check_circle_rounded, color: AppColors.green, size: 21),
              ),
          ],
        ),
      ),
    );
  }
}

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final Address? address;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _line;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postal;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late bool _isDefault;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _label = TextEditingController(text: address?.label ?? 'Home');
    _line = TextEditingController(text: address?.addressLine ?? '');
    _city = TextEditingController(text: address?.city ?? 'Indore');
    _state = TextEditingController(text: address?.state ?? 'Madhya Pradesh');
    _postal = TextEditingController(text: address?.postalCode ?? '');
    _lat = TextEditingController(text: address?.latitude.toString() ?? '22.7533');
    _lng = TextEditingController(text: address?.longitude.toString() ?? '75.8937');
    _isDefault = address?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final controller in [_label, _line, _city, _state, _postal, _lat, _lng]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'label': _label.text.trim(),
      'addressLine': _line.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'postalCode': _postal.text.trim(),
      'latitude': double.parse(_lat.text.trim()),
      'longitude': double.parse(_lng.text.trim()),
      'isDefault': _isDefault,
    };
    try {
      final provider = context.read<LocationProvider>();
      if (widget.address == null) {
        await provider.createAddress(body);
      } else {
        await provider.updateAddress(widget.address!.id, body);
        if (_isDefault) await provider.makeDefault(widget.address!.id);
      }
      if (!mounted) return;
      showMessage(context, widget.address == null ? 'Address added.' : 'Address updated.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.address == null ? 'Add address' : 'Edit address')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _label,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Label',
                              hintText: 'Home, Office, Parents…',
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _line,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'House / street / area',
                              alignLabelWithHint: true,
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _city,
                                  decoration: const InputDecoration(labelText: 'City'),
                                  validator: _required,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _state,
                                  decoration: const InputDecoration(labelText: 'State'),
                                  validator: _required,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _postal,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'PIN code'),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length < 4 || text.length > 10) {
                                return 'Enter a valid PIN code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _lat,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Latitude'),
                                  validator: _coordinate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lng,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Longitude'),
                                  validator: _coordinate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: AppColors.green,
                            title: const Text(
                              'Use as my default address',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            value: _isDefault,
                            onChanged: (value) => setState(() => _isDefault = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save address'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tip: the demo stores are around Vijay Nagar, Indore. Keep these coordinates to test nearby shop selection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.4),
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  String? _coordinate(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Enter a number';
    if (number < -180 || number > 180) return 'Out of range';
    return null;
  }
}
