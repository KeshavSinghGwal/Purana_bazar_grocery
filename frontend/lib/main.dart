import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'state/auth_provider.dart';
import 'state/cart_provider.dart';
import 'state/language_provider.dart';
import 'state/location_provider.dart';
import 'state/notification_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final api = ApiClient.instance;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider(preferences)),
        ChangeNotifierProvider(create: (_) => AuthProvider(preferences)),
        ChangeNotifierProvider(
          create: (context) =>
              NotificationProvider(api, context.read<AuthProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => LocationProvider(api)),
        ChangeNotifierProvider(create: (_) => CartProvider(api)),
      ],
      child: const PuranaBazaarApp(),
    ),
  );
}
