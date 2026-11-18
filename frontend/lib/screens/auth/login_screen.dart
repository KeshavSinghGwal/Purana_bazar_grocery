import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/language_selector.dart';
import 'register_screen.dart';
import 'shop_owner_register_screen.dart';
import '../../core/localization.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().login(_email.text, _password.text);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not sign in. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _useDemo(String email, String password) {
    setState(() {
      _email.text = email;
      _password.text = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          Positioned(
            top: -170,
            right: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: -90,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: AppColors.paleMint,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppLogo(),
                      const SizedBox(height: 40),
                      AppText(
                        'Fresh groceries,\nfrom your neighbourhood.',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      const AppText(
                        'Choose the best nearby shop for your entire cart, or shop directly from a store you love.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AppCard(
                        padding: const EdgeInsets.all(22),
                        radius: 24,
                        shadow: true,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 5),
                              const AppText(
                                'Sign in to continue shopping.',
                                style: TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'Email address'),
                                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return AppLocalizations.current.tr('Enter your email address');
                                  }
                                  if (!value.contains('@')) return AppLocalizations.current.tr('Enter a valid email');
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: tr(context, 'Password'),
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Enter your password'
                                    : null,
                              ),
                              const SizedBox(height: 20),
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
                                      : const AppText('Sign in'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const AppText(
                                    'New to Purana Bazaar?',
                                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    ),
                                    child: const AppText('Create account'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: AppText(
                              'TRY A DEMO ACCOUNT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _demoChip('Customer', 'customer@puranabazaar.com', 'Customer@123'),
                          _demoChip('Shop owner', 'sharma@puranabazaar.com', 'Owner@123'),
                          _demoChip('Delivery', 'delivery@puranabazaar.com', 'Delivery@123'),
                          _demoChip('Admin', 'admin@puranabazaar.com', 'Admin@123'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShopOwnerRegisterScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_outlined, size: 18),
                          label: const AppText('Register your shop'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: AppText(
                          'By continuing you agree to fair-use and local delivery policies.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: AppColors.soft),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: SafeArea(child: LanguageButton()),
          ),
        ],
      ),
    );
  }

  Widget _demoChip(String label, String email, String password) {
    return ActionChip(
      avatar: const Icon(Icons.person_outline_rounded, size: 16),
      label: AppText(label),
      onPressed: () => _useDemo(email, password),
    );
  }
}
