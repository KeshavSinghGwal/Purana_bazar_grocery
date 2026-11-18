import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:purana_bazaar/core/localization.dart';
import 'package:purana_bazaar/state/language_provider.dart';
import 'package:purana_bazaar/widgets/language_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('hi')],
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  test('English is returned unchanged by default', () {
    expect(AppLocalizations.english.tr('Profile'), 'Profile');
    expect(AppLocalizations.english.tr('Your cart'), 'Your cart');
  });

  test('Hindi dictionary translates copy', () {
    const hindi = AppLocalizations.hindi;
    expect(hindi.tr('Profile'), 'प्रोफ़ाइल');
    expect(hindi.tr('Your cart'), 'आपका कार्ट');
    expect(hindi.tr('Sign out'), 'साइन आउट');
    // Unknown copy falls back to English instead of breaking the UI.
    expect(hindi.tr('Some future string'), 'Some future string');
  });

  test('Hindi templates keep dynamic values', () {
    const hindi = AppLocalizations.hindi;
    expect(hindi.tr('Only 3 left'), 'केवल 3 बचे');
    expect(hindi.tr('12 min'), '12 मिनट');
    expect(hindi.tr('Milk + 2 more'), 'Milk + 2 और');
  });

  test('server messages and catalog copy are translated', () {
    const hindi = AppLocalizations.hindi;
    expect(hindi.tr('Incorrect email or password.'), 'ईमेल या पासवर्ड गलत है।');
    expect(hindi.tr('Your cart is empty.'), 'आपका कार्ट खाली है।');
    expect(hindi.tr('Dairy & Eggs'), 'डेयरी और अंडे');
    expect(hindi.tr('Order delivered'), 'ऑर्डर डिलीवर हुआ');
  });

  test('server notifications and quote reasons keep dynamic values', () {
    const hindi = AppLocalizations.hindi;
    expect(
      hindi.tr('Order PB-1042 is on its way to you.'),
      'ऑर्डर PB-1042 आपकी ओर रास्ते में है।',
    );
    expect(
      hindi.tr('Sharma General Store accepted order PB-1042 and will start packing it.'),
      'Sharma General Store ने ऑर्डर PB-1042 स्वीकार किया और उसे पैक करना शुरू करेगा।',
    );
    expect(
      hindi.tr('Outside delivery radius (5.0 km)'),
      'डिलीवरी दायरे से बाहर (5.0 किमी)',
    );
    expect(
      hindi.tr('Order PB-1042 is confirmed with Sharma General Store. Pay ₹450 on delivery.'),
      'ऑर्डर PB-1042 Sharma General Store के साथ पुष्टि हो गया। डिलीवरी पर ₹450 का भुगतान करें।',
    );
  });

  testWidgets('AppText follows the active locale', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), const AppText('Profile')));
    expect(find.text('Profile'), findsOneWidget);

    await tester.pumpWidget(_app(const Locale('hi'), const AppText('Profile')));
    await tester.pumpAndSettle();
    expect(find.text('प्रोफ़ाइल'), findsOneWidget);
  });

  testWidgets('language picker switches the app to Hindi', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = LanguageProvider(preferences);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return MaterialApp(
              locale: language.locale,
              supportedLocales: const [Locale('en'), Locale('hi')],
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: Builder(
                  builder: (innerContext) {
                    return Column(
                      children: [
                        const AppText('Profile'),
                        ElevatedButton(
                          onPressed: () => showLanguagePicker(innerContext),
                          child: const AppText('Choose language'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Choose language'));
    await tester.pumpAndSettle();
    expect(find.text('हिन्दी'), findsOneWidget);

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(provider.language, AppLanguage.hindi);
    expect(find.text('प्रोफ़ाइल'), findsOneWidget);
    expect(preferences.getString(LanguageProvider.storageKey), 'hi');
  });
}
