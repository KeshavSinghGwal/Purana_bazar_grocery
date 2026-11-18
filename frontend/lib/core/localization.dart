import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Languages supported by Purana Bazaar.
enum AppLanguage { english, hindi }

/// Lightweight English -> Hindi localization layer.
///
/// English is the source language, so UI copy can stay readable in code and
/// simply be looked up in the Hindi dictionary at render time. Strings that do
/// not have a translation fall back to English, which keeps the app usable
/// while new copy is added.
class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  static const AppLocalizations english = AppLocalizations(AppLanguage.english);
  static const AppLocalizations hindi = AppLocalizations(AppLanguage.hindi);

  /// Kept in sync by [LanguageProvider] so helpers without a [BuildContext]
  /// (for example status labels and snackbar messages) can localize too.
  static AppLocalizations current = english;

  bool get isHindi => language == AppLanguage.hindi;

  Locale get locale => isHindi ? const Locale('hi') : const Locale('en');

  String get languageName => isHindi ? 'हिन्दी' : 'English';

  String tr(String source) {
    if (!isHindi || source.isEmpty) return source;
    final exact = _hindi[source];
    if (exact != null) return exact;
    for (final rule in _templateRules) {
      final match = rule.pattern.firstMatch(source);
      if (match != null) return rule.translate(match);
    }
    return source;
  }

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? current;
}

/// Translate a raw string for the current locale.
String tr(BuildContext context, String source) =>
    AppLocalizations.of(context).tr(source);

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String source) => AppLocalizations.of(this).tr(source);
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'hi';

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
        locale.languageCode == 'hi'
            ? AppLocalizations.hindi
            : AppLocalizations.english,
      );

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

/// Drop-in replacement for [Text] that renders copy in the selected language.
///
/// All existing screens use this widget so switching the language updates the
/// whole app without every screen needing its own translation lookup.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

class _TemplateRule {
  const _TemplateRule(this.pattern, this.translate);

  final RegExp pattern;
  final String Function(Match match) translate;
}

final List<_TemplateRule> _templateRules = [
  _TemplateRule(RegExp(r'^Only (.+) left$'), (m) => 'केवल ${m[1]} बचे'),
  _TemplateRule(RegExp(r'^Only (.+) available$'), (m) => 'केवल ${m[1]} उपलब्ध'),
  _TemplateRule(RegExp(r'^(.+) of (.+) products$'), (m) => '${m[1]} / ${m[2]} उत्पाद'),
  _TemplateRule(RegExp(r'^(.+) products$'), (m) => '${m[1]} उत्पाद'),
  _TemplateRule(RegExp(r'^(.+) approved shops$'), (m) => '${m[1]} स्वीकृत दुकानें'),
  _TemplateRule(RegExp(r'^(.+) shops can deliver here$'), (m) => '${m[1]} दुकानें यहाँ डिलीवर कर सकती हैं'),
  _TemplateRule(RegExp(r'^(.+) shops$'), (m) => '${m[1]} दुकानें'),
  _TemplateRule(RegExp(r'^(.+) items$'), (m) => '${m[1]} सामान'),
  _TemplateRule(RegExp(r'^(.+) in stock$'), (m) => '${m[1]} स्टॉक में'),
  _TemplateRule(RegExp(r'^(.+) min$'), (m) => '${m[1]} मिनट'),
  _TemplateRule(RegExp(r'^(.+) km$'), (m) => '${m[1]} किमी'),
  _TemplateRule(RegExp(r'^Add (.+) more for free delivery$'), (m) => 'मुफ़्त डिलीवरी के लिए ${m[1]} और जोड़ें'),
  _TemplateRule(RegExp(r'^Welcome, (.+)$'), (m) => 'स्वागत है, ${m[1]}'),
  _TemplateRule(RegExp(r'^Hello, (.+)\.$'), (m) => 'नमस्ते, ${m[1]}।'),
  _TemplateRule(RegExp(r'^Placed (.+)$'), (m) => '${m[1]} को किया गया'),
  _TemplateRule(RegExp(r'^Delivering to (.+)$'), (m) => '${m[1]} पर डिलीवरी'),
  _TemplateRule(RegExp(r'^Owned by (.+)$'), (m) => 'मालिक: ${m[1]}'),
  _TemplateRule(RegExp(r'^Rate (.+)$'), (m) => '${m[1]} को रेट करें'),
  _TemplateRule(RegExp(r'^Reason: (.+)$'), (m) => 'कारण: ${m[1]}'),
  _TemplateRule(RegExp(r'^Customer note: (.+)$'), (m) => 'ग्राहक नोट: ${m[1]}'),
  _TemplateRule(RegExp(r'^Note: (.+)$'), (m) => 'नोट: ${m[1]}'),
  _TemplateRule(RegExp(r'^Cancel (.+)\?$'), (m) => '${m[1]} रद्द करें?'),
  _TemplateRule(RegExp(r'^Display order (.+) · ID #(.+)$'), (m) => 'क्रम ${m[1]} · आईडी #${m[2]}'),
  _TemplateRule(RegExp(r'^Remove (.+) from your saved addresses\?$'), (m) => '${m[1]} को अपने सहेजे गए पतों से हटाएं?'),
  _TemplateRule(RegExp(r'^Pay ₹(.+) for order (.+)\?$'), (m) => 'ऑर्डर ${m[2]} के लिए ₹${m[1]} का भुगतान करें?'),
  _TemplateRule(RegExp(r'^(.+) added to cart\.$'), (m) => '${m[1]} कार्ट में जोड़ा गया।'),
  _TemplateRule(RegExp(r'^Thanks for reviewing (.+)\.$'), (m) => '${m[1]} की समीक्षा के लिए धन्यवाद।'),
  _TemplateRule(RegExp(r'^Order marked (.+)\.$'), (m) => 'ऑर्डर ${m[1]} के रूप में चिह्नित किया गया।'),
  _TemplateRule(RegExp(r'^(.+) is now yours\. Pick it up from (.+)\.$'), (m) => '${m[1]} अब आपका है। इसे ${m[2]} से ले जाएं।'),
  _TemplateRule(RegExp(r'^Collect (.+)$'), (m) => '${m[1]} लें'),
  _TemplateRule(RegExp(r'^Prepaid · (.+)$'), (m) => 'प्रीपेड · ${m[1]}'),
  _TemplateRule(RegExp(r'^Secured by (.+)$'), (m) => '${m[1]} द्वारा सुरक्षित'),
  _TemplateRule(RegExp(r'^(\d+) order is waiting for pickup nearby\.$'), (m) => 'आस-पास ${m[1]} ऑर्डर पिकअप का इंतज़ार कर रहा है।'),
  _TemplateRule(RegExp(r'^(\d+) orders are waiting for pickup nearby\.$'), (m) => 'आस-पास ${m[1]} ऑर्डर पिकअप का इंतज़ार कर रहे हैं।'),
  _TemplateRule(RegExp(r'^(\d+) ready orders? nearby$'), (m) => 'आस-पास ${m[1]} तैयार ऑर्डर'),
  _TemplateRule(RegExp(r'^(.+) \+ (\d+) more$'), (m) => '${m[1]} + ${m[2]} और'),
  _TemplateRule(RegExp(r'^(\d+) items? · incl\. delivery$'), (m) => '${m[1]} सामान · डिलीवरी सहित'),
  _TemplateRule(RegExp(r'^(\d+) live listings · prices and stock from this shop$'), (m) => '${m[1]} लाइव लिस्टिंग · इस दुकान के दाम और स्टॉक'),
  _TemplateRule(RegExp(r'^(.+) min · (.+)$'), (m) => '${m[1]} मिनट · ${_translateSegment(m[2]!)}'),
  _TemplateRule(RegExp(r'^(Product Choice|Shop Choice) · (.+) min$'), (m) => '${_translateSegment(m[1]!)} · ${m[2]} मिनट'),
  _TemplateRule(RegExp(r'^(.+) · (.+) each$'), (m) => '${m[1]} · ${m[2]} प्रति'),
  _TemplateRule(RegExp(r'^(.+) · (.+) km trip$'), (m) => '${m[1]} · ${m[2]} किमी यात्रा'),
  _TemplateRule(RegExp(r'^(.+) · Neighbourhood store$'), (m) => '${m[1]} · मोहल्ले की दुकान'),
  _TemplateRule(RegExp(r'^(.+) listing(s?) out of stock\. Update stock to stay visible\.$'), (m) => '${m[1]} लिस्टिंग स्टॉक में नहीं। दिखते रहने के लिए स्टॉक अपडेट करें।'),
  _TemplateRule(RegExp(r'^(.+) will be hidden from the customer catalog\. Products in it stay in the database and can be reactivated later\.$'), (m) => '${m[1]} ग्राहक कैटलॉग से छिप जाएगी। इसमें मौजूद उत्पाद डेटाबेस में रहेंगे और बाद में फिर सक्रिय किए जा सकते हैं।'),
  _TemplateRule(RegExp(r'^(.+) will be hidden from customers and its stock will be set to zero\. Existing orders are not affected\.$'), (m) => '${m[1]} ग्राहकों से छिप जाएगा और इसका स्टॉक शून्य कर दिया जाएगा। मौजूदा ऑर्डर प्रभावित नहीं होंगे।'),
  _TemplateRule(RegExp(r'^(.+) will be hidden from the customer catalog\. Shops already listing it will keep their inventory records\.$'), (m) => '${m[1]} ग्राहक कैटलॉग से छिप जाएगा। इसे पहले से सूचीबद्ध करने वाली दुकानों की इन्वेंटरी रिकॉर्ड रहेंगी।'),
  _TemplateRule(RegExp(r'^(.+) will become visible to customers and can start receiving orders immediately\.$'), (m) => '${m[1]} ग्राहकों को दिखने लगेगी और तुरंत ऑर्डर लेना शुरू कर सकती है।'),
  _TemplateRule(RegExp(r'^(.+) — requested (.+), max (.+)$'), (m) => '${m[1]} — अनुरोधित ${m[2]}, अधिकतम ${m[3]}'),
  _TemplateRule(RegExp(r'^(.+) will no longer be able to sign in or place orders\. Existing orders are not affected\.$'), (m) => '${m[1]} अब साइन इन या ऑर्डर नहीं कर पाएंगे। मौजूदा ऑर्डर प्रभावित नहीं होंगे।'),
  _TemplateRule(RegExp(r'^(.+) will be able to sign in and order again\.$'), (m) => '${m[1]} फिर से साइन इन और ऑर्डर कर पाएंगे।'),
  // Server-side order, payment and shop notifications.
  _TemplateRule(
      RegExp(r'^Order (.+) is reserved for you\. Pay ₹(.+) to confirm it with (.+)\.$'),
      (m) => 'ऑर्डर ${m[1]} आपके लिए सुरक्षित है। ${m[3]} के साथ पुष्टि करने के लिए ₹${m[2]} का भुगतान करें।'),
  _TemplateRule(
      RegExp(r'^Order (.+) is confirmed with (.+)\. Pay ₹(.+) on delivery\.$'),
      (m) => 'ऑर्डर ${m[1]} ${m[2]} के साथ पुष्टि हो गया। डिलीवरी पर ₹${m[3]} का भुगतान करें।'),
  _TemplateRule(
      RegExp(r'^Order (.+) from (.+) · ₹(.+)\. Accept it to start packing\.$'),
      (m) => '${m[2]} से ऑर्डर ${m[1]} · ₹${m[3]}। पैकिंग शुरू करने के लिए स्वीकार करें।'),
  _TemplateRule(
      RegExp(r'^(.+) accepted order (.+) and will start packing it\.$'),
      (m) => '${m[1]} ने ऑर्डर ${m[2]} स्वीकार किया और उसे पैक करना शुरू करेगा।'),
  _TemplateRule(
      RegExp(r'^Order (.+) is being prepared at (.+)\.$'),
      (m) => 'ऑर्डर ${m[1]} ${m[2]} पर तैयार किया जा रहा है।'),
  _TemplateRule(
      RegExp(r'^Order (.+) is packed and waiting for a delivery partner\.$'),
      (m) => 'ऑर्डर ${m[1]} पैक हो गया है और डिलीवरी पार्टनर का इंतज़ार कर रहा है।'),
  _TemplateRule(
      RegExp(r'^Order (.+) is on its way to you\.$'),
      (m) => 'ऑर्डर ${m[1]} आपकी ओर रास्ते में है।'),
  _TemplateRule(
      RegExp(r'^Order (.+) has been delivered\. Enjoy your groceries!$'),
      (m) => 'ऑर्डर ${m[1]} डिलीवर हो गया। अपनी किराने का आनंद लें!'),
  _TemplateRule(
      RegExp(r'^Unfortunately (.+) could not accept order (.+)\. Any payment will be refunded\.$'),
      (m) => 'दुर्भाग्य से ${m[1]} ऑर्डर ${m[2]} स्वीकार नहीं कर सका। कोई भी भुगतान वापस कर दिया जाएगा।'),
  _TemplateRule(
      RegExp(r'^Order (.+) was cancelled by the shop\.$'),
      (m) => 'ऑर्डर ${m[1]} दुकान द्वारा रद्द कर दिया गया।'),
  _TemplateRule(
      RegExp(r'^Order (.+) was cancelled because the payment was not completed\. Reserved stock was released\.$'),
      (m) => 'भुगतान पूरा न होने के कारण ऑर्डर ${m[1]} रद्द कर दिया गया। आरक्षित स्टॉक जारी कर दिया गया।'),
  _TemplateRule(
      RegExp(r'^(.+) will deliver order (.+)\. They will call you if needed\.$'),
      (m) => '${m[1]} ऑर्डर ${m[2]} डिलीवर करेंगे। ज़रूरत पड़ी तो वे आपको कॉल करेंगे।'),
  _TemplateRule(
      RegExp(r'^(.+) accepted order (.+) for pickup\.$'),
      (m) => '${m[1]} ने ऑर्डर ${m[2]} पिकअप के लिए स्वीकार किया।'),
  _TemplateRule(
      RegExp(r'^Payment for order (.+) did not go through\. You can retry the payment from the order screen\.$'),
      (m) => 'ऑर्डर ${m[1]} का भुगतान नहीं हो सका। आप ऑर्डर स्क्रीन से भुगतान फिर आज़मा सकते हैं।'),
  _TemplateRule(
      RegExp(r'^A refund of ₹(.+) has been initiated for order (.+)\. It usually reaches your account in 5–7 working days\.$'),
      (m) => 'ऑर्डर ${m[2]} के लिए ₹${m[1]} का रिफ़ंड शुरू किया गया है। यह आमतौर पर 5–7 कार्य दिवसों में आपके खाते में पहुँचता है।'),
  _TemplateRule(
      RegExp(r'^We received ₹(.+) for order (.+)\. The shop will confirm it shortly\.$'),
      (m) => 'ऑर्डर ${m[2]} के लिए ₹${m[1]} प्राप्त हुआ। दुकान जल्द इसकी पुष्टि करेगी।'),
  _TemplateRule(
      RegExp(r'^Order (.+) from (.+) is paid \(₹(.+)\)\. Please accept it\.$'),
      (m) => '${m[2]} से ऑर्डर ${m[1]} का भुगतान हो गया (₹${m[3]})। कृपया इसे स्वीकार करें।'),
  _TemplateRule(
      RegExp(r'^(.+) is now live on Purana Bazaar\. Customers can find and order from you\.$'),
      (m) => '${m[1]} अब Purana Bazaar पर लाइव है। ग्राहक आपको ढूंढकर ऑर्डर कर सकते हैं।'),
  _TemplateRule(
      RegExp(r'^Your shop (.+) could not be approved\. Reason: (.+)$'),
      (m) => 'आपकी दुकान ${m[1]} स्वीकृत नहीं हो सकी। कारण: ${m[2]}'),
  _TemplateRule(
      RegExp(r'^Your shop (.+) could not be approved\.$'),
      (m) => 'आपकी दुकान ${m[1]} स्वीकृत नहीं हो सकी।'),
  _TemplateRule(
      RegExp(r'^(.+) is pending administrator approval\. We will notify you as soon as it is reviewed\.$'),
      (m) => '${m[1]} एडमिन स्वीकृति की प्रतीक्षा में है। समीक्षा होते ही हम आपको सूचित करेंगे।'),
  // Shop-selection quote copy.
  _TemplateRule(
      RegExp(r'^Nearest shop that can fulfil your complete cart: (.+)$'),
      (m) => 'आपका पूरा कार्ट पूरा करने वाली निकटतम दुकान: ${m[1]}'),
  _TemplateRule(
      RegExp(r'^(\d+) items are unavailable in the requested quantity$'),
      (m) => 'अनुरोधित मात्रा में ${m[1]} सामान उपलब्ध नहीं हैं'),
  _TemplateRule(
      RegExp(r'^Outside delivery radius \((.+) km\)$'),
      (m) => 'डिलीवरी दायरे से बाहर (${m[1]} किमी)'),
  _TemplateRule(
      RegExp(r'^Cannot change order status from (.+) to (.+)\.$'),
      (m) => 'ऑर्डर की स्थिति ${m[1]} से ${m[2]} नहीं बदली जा सकती।'),
  _TemplateRule(RegExp(r'^(.+) · (.+)$'), (m) => '${_translateSegment(m[1]!)} · ${_translateSegment(m[2]!)}'),
];

String _translateSegment(String part) {
  final exact = _hindi[part];
  if (exact != null) return exact;
  final min = RegExp(r'^(\d+) min$').firstMatch(part);
  if (min != null) return '${min[1]} मिनट';
  final km = RegExp(r'^(\d+(?:\.\d+)?) km$').firstMatch(part);
  if (km != null) return '${km[1]} किमी';
  final items = RegExp(r'^(\d+) items?$').firstMatch(part);
  if (items != null) return '${items[1]} सामान';
  final shops = RegExp(r'^(\d+) shops?$').firstMatch(part);
  if (shops != null) return '${shops[1]} दुकानें';
  return part;
}

const Map<String, String> _hindi = {
  // ---------------------------------------------------------------------------
  // Common actions and labels
  // ---------------------------------------------------------------------------
  'ADD': 'जोड़ें',
  'Add': 'जोड़ें',
  'Add address': 'पता जोड़ें',
  'Add another address': 'दूसरा पता जोड़ें',
  'Add delivery address': 'डिलीवरी पता जोड़ें',
  'Add listing': 'लिस्टिंग जोड़ें',
  'Add more items': 'और सामान जोड़ें',
  'Add to cart': 'कार्ट में जोड़ें',
  'All': 'सभी',
  'All items': 'सभी सामान',
  'All items and the selected shopping mode will be removed.':
      'सभी सामान और चुना गया खरीद तरीका हटा दिए जाएंगे।',
  'All orders': 'सभी ऑर्डर',
  'Approve': 'स्वीकृत करें',
  'Approve this shop?': 'इस दुकान को स्वीकृत करें?',
  'Available': 'उपलब्ध',
  'Available pickups': 'उपलब्ध पिकअप',
  'Back': 'वापस',
  'Best price': 'सबसे अच्छा दाम',
  'Cancel': 'रद्द करें',
  'Cancel order': 'ऑर्डर रद्द करें',
  'Cancel this order': 'यह ऑर्डर रद्द करें',
  'Cancel this order?': 'यह ऑर्डर रद्द करें?',
  'Change': 'बदलें',
  'Check again': 'फिर जांचें',
  'Checkout': 'चेकआउट',
  'Clear': 'हटाएं',
  'Clear cart': 'कार्ट खाली करें',
  'Clear your cart?': 'अपना कार्ट खाली करें?',
  'Close': 'बंद करें',
  'Completed': 'पूर्ण',
  'Confirm': 'पुष्टि करें',
  'Continue shopping': 'खरीदारी जारी रखें',
  'Create account': 'खाता बनाएं',
  'Create my account': 'मेरा खाता बनाएं',
  'Delete': 'हटाएं',
  'Delete address?': 'पता हटाएं?',
  'Deactivate': 'निष्क्रिय करें',
  'Deactivate category?': 'श्रेणी निष्क्रिय करें?',
  'Deactivate product?': 'उत्पाद निष्क्रिय करें?',
  'Details': 'विवरण',
  'Edit cart': 'कार्ट बदलें',
  'Edit category': 'श्रेणी बदलें',
  'Edit product': 'उत्पाद बदलें',
  'Deactivate category': 'श्रेणी निष्क्रिय करें',
  'Deactivate product': 'उत्पाद निष्क्रिय करें',
  'Edit profile': 'प्रोफ़ाइल बदलें',
  'Edit shop': 'दुकान बदलें',
  'Edit shop details': 'दुकान का विवरण बदलें',
  'Find shop': 'दुकान खोजें',
  'Got it': 'समझ गया',
  'Keep': 'रखें',
  'Keep items': 'सामान रखें',
  'Keep order': 'ऑर्डर रखें',
  'Manage inventory': 'इन्वेंटरी प्रबंधित करें',
  'Manage order status': 'ऑर्डर स्थिति प्रबंधित करें',
  'Manage orders': 'ऑर्डर प्रबंधित करें',
  'Mark all read': 'सभी पढ़े हुए चिह्नित करें',
  'New category': 'नई श्रेणी',
  'New product': 'नया उत्पाद',
  'Not now': 'अभी नहीं',
  'Proceed to checkout': 'चेकआउट पर जाएं',
  'Reactivate': 'पुनः सक्रिय करें',
  'Reject': 'अस्वीकार करें',
  'Remove': 'हटाएं',
  'Remove listing?': 'लिस्टिंग हटाएं?',
  'Retry': 'पुनः प्रयास करें',
  'Review cart & checkout': 'कार्ट देखें और चेकआउट करें',
  'Save': 'सहेजें',
  'Save address': 'पता सहेजें',
  'Save changes': 'बदलाव सहेजें',
  'Set as default': 'डिफ़ॉल्ट बनाएं',
  'Sign in': 'साइन इन',
  'Sign out': 'साइन आउट',
  'Sign out?': 'साइन आउट करें?',
  'Simulate payment': 'भुगतान सिम्युलेट करें',
  'Stay': 'रहें',
  'Submit': 'जमा करें',
  'Submit review': 'समीक्षा जमा करें',
  'Submit shop for approval': 'दुकान स्वीकृति के लिए भेजें',
  'Suspend': 'निलंबित करें',
  'Track this order': 'इस ऑर्डर को ट्रैक करें',
  'Try again': 'फिर से प्रयास करें',
  'Update status': 'स्थिति अपडेट करें',
  'Use as my default address': 'इसे मेरा डिफ़ॉल्ट पता बनाएं',
  'View details': 'विवरण देखें',
  'View': 'देखें',
  'Add listing or edit it': 'लिस्टिंग जोड़ें या बदलें',

  // ---------------------------------------------------------------------------
  // Navigation and shell labels
  // ---------------------------------------------------------------------------
  'Home': 'होम',
  'Shops': 'दुकानें',
  'Orders': 'ऑर्डर',
  'Wishlist': 'पसंदीदा',
  'Profile': 'प्रोफ़ाइल',
  'Dashboard': 'डैशबोर्ड',
  'Inventory': 'इन्वेंटरी',
  'My shop': 'मेरी दुकान',
  'Overview': 'अवलोकन',
  'Deliveries': 'डिलीवरी',
  'Customers': 'ग्राहक',
  'Catalog': 'कैटलॉग',
  'Delivery': 'डिलीवरी',

  // ---------------------------------------------------------------------------
  // Customer home, shops and products
  // ---------------------------------------------------------------------------
  'A flat ₹19 delivery fee applies to smaller orders. The nearest eligible shop is chosen at checkout.':
      'छोटे ऑर्डर पर ₹19 का स्थिर डिलीवरी शुल्क लागू होता है। चेकआउट पर निकटतम पात्र दुकान चुनी जाती है।',
  'About this product': 'इस उत्पाद के बारे में',
  'Accepting orders': 'ऑर्डर स्वीकार रहे हैं',
  'Active category': 'सक्रिय श्रेणी',
  'Active categories': 'सक्रिय श्रेणियाँ',
  'Active in catalog': 'कैटलॉग में सक्रिय',
  'Active customers': 'सक्रिय ग्राहक',
  'Add a catalog product': 'कैटलॉग उत्पाद जोड़ें',
  'Admin console': 'एडमिन कंसोल',
  'Admin note': 'एडमिन नोट',
  'Approve shops, watch orders and curate the catalog from one place.':
      'एक ही जगह से दुकानें स्वीकृत करें, ऑर्डर देखें और कैटलॉग सँभालें।',
  'Approved shops': 'स्वीकृत दुकानें',
  'Be the first to review this shop after a delivered order.':
      'डिलीवरी के बाद इस दुकान की समीक्षा करने वाले पहले व्यक्ति बनें।',
  'Choose a product, then set your shop price and stock.':
      'उत्पाद चुनें, फिर अपनी दुकान का दाम और स्टॉक सेट करें।',
  'Choose the best nearby shop for your entire cart, or shop directly from a store you love.':
      'अपने पूरे कार्ट के लिए आस-पास की सबसे अच्छी दुकान चुनें, या सीधे अपनी पसंद की दुकान से खरीदें।',
  'Choose the next status. Stock is restored automatically for rejections or cancellations.':
      'अगली स्थिति चुनें। अस्वीकृति या रद्द होने पर स्टॉक अपने आप बहाल हो जाता है।',
  'Close the shop for a short break without losing settings.':
      'सेटिंग्स खोए बिना थोड़े समय के लिए दुकान बंद करें।',
  'Could not load this page': 'यह पेज लोड नहीं हो सका',
  'Create a customer account to order from verified neighbourhood shops.':
      'सत्यापित आस-पास की दुकानों से ऑर्डर करने के लिए ग्राहक खाता बनाएं।',
  'Current status': 'वर्तमान स्थिति',
  'DEFAULT': 'डिफ़ॉल्ट',
  'DELIVER TO': 'यहाँ डिलीवर करें',
  'DELIVERING TO': 'यहाँ डिलीवरी',
  'Delivery available': 'डिलीवरी उपलब्ध',
  'Delivery charge': 'डिलीवरी शुल्क',
  'Delivery details': 'डिलीवरी विवरण',
  'Delivery instructions': 'डिलीवरी निर्देश',
  'Delivery note': 'डिलीवरी नोट',
  'Delivery radius': 'डिलीवरी दायरा',
  'Delivery desk': 'डिलीवरी डेस्क',
  'Delivering to': 'यहाँ डिलीवरी',
  'Bill details': 'बिल विवरण',
  'Bill summary': 'बिल सारांश',
  'By continuing you agree to fair-use and local delivery policies.':
      'आगे बढ़ने पर आप उचित उपयोग और स्थानीय डिलीवरी नीतियों से सहमत होते हैं।',
  'Everyday essentials. Nearby shops. One bazaar.':
      'रोज़ की ज़रूरतें। आस-पास की दुकानें। एक बाज़ार।',
  'Everything is reviewed. New shop registrations will appear here.':
      'हर चीज़ की समीक्षा होती है। नई दुकानों के रजिस्ट्रेशन यहाँ दिखेंगे।',
  'Final prices and delivery are confirmed by the server at checkout.':
      'अंतिम दाम और डिलीवरी की पुष्टि चेकआउट पर सर्वर द्वारा की जाती है।',
  'For demo support, contact support@puranabazaar.com. You can cancel orders in Pending, Accepted or Preparing states from the order details screen. Delivered orders can be reviewed.':
      'डेमो सहायता के लिए support@puranabazaar.com पर संपर्क करें। आप ऑर्डर विवरण स्क्रीन से लंबित, स्वीकृत या तैयारी में वाले ऑर्डर रद्द कर सकते हैं। डिलीवर हो चुके ऑर्डर की समीक्षा की जा सकती है।',
  'Free delivery above ₹199': '₹199 से अधिक पर मुफ़्त डिलीवरी',
  'Fresh groceries,\nfrom your neighbourhood.':
      'ताज़ा किराना,\nआपके मोहल्ले से।',
  'Fulfilment check': 'पूर्ति जांच',
  'Help & support': 'सहायता और सहयोग',
  'I already have an account': 'मेरा पहले से खाता है',
  'Inactive products disappear from customer search.':
      'निष्क्रिय उत्पाद ग्राहक खोज से गायब हो जाते हैं।',
  'Items': 'सामान',
  'Items being fulfilled': 'पूरे किए जा रहे सामान',
  'LIVE': 'लाइव',
  'Listing active': 'लिस्टिंग सक्रिय',
  'Locally sourced · Shop-verified stock · Delivery radius enforced':
      'स्थानीय रूप से प्राप्त · दुकान से सत्यापित स्टॉक · डिलीवरी दायरा लागू',
  'MARKETPLACE CONTROL': 'मार्केटप्लेस नियंत्रण',
  'My deliveries': 'मेरी डिलीवरी',
  'My orders': 'मेरे ऑर्डर',
  'NEIGHBOURHOOD GROCERY': 'मोहल्ले का किराना',
  'Nearest first': 'पहले निकटतम',
  'New shops go live after an administrator checks your details. You can set up inventory right away.':
      'एडमिन द्वारा विवरण जांचे जाने के बाद नई दुकानें लाइव होती हैं। आप अभी इन्वेंटरी सेट कर सकते हैं।',
  'New to Purana Bazaar?': 'Purana Bazaar पर नए हैं?',
  'No active delivery. Accept a pickup from the Available tab to get started.':
      'कोई सक्रिय डिलीवरी नहीं। शुरू करने के लिए उपलब्ध टैब से पिकअप स्वीकार करें।',
  'No money is charged in test mode.': 'टेस्ट मोड में कोई पैसा नहीं कटता।',
  'No orders yet. Once a customer checks out, their order will appear here for acceptance.':
      'अभी कोई ऑर्डर नहीं। ग्राहक के चेकआउट करते ही ऑर्डर यहाँ स्वीकृति के लिए दिखेगा।',
  'No delivery address selected': 'कोई डिलीवरी पता नहीं चुना गया',
  'No description': 'कोई विवरण नहीं',
  'No phone': 'फ़ोन नहीं',
  'No items': 'कोई सामान नहीं',
  'No pickups waiting right now. We will keep this desk fresh.':
      'अभी कोई पिकअप इंतज़ार में नहीं है। हम यह डेस्क ताज़ा रखेंगे।',
  'Notifications': 'सूचनाएं',
  'ON DUTY': 'ड्यूटी पर',
  'ORDER NUMBER': 'ऑर्डर नंबर',
  'One cart, one shop': 'एक कार्ट, एक दुकान',
  'Only hand over an order after collecting payment for COD deliveries.':
      'COD डिलीवरी में भुगतान लेने के बाद ही ऑर्डर सौंपें।',
  'Order confirmed!': 'ऑर्डर की पुष्टि हो गई!',
  'Order details': 'ऑर्डर विवरण',
  'Order items': 'ऑर्डर के सामान',
  'Order progress': 'ऑर्डर की प्रगति',
  'Out of stock': 'स्टॉक में नहीं',
  'Owner dashboard': 'दुकान मालिक डैशबोर्ड',
  'Partner with Purana Bazaar': 'Purana Bazaar के साथ जुड़ें',
  'Payment': 'भुगतान',
  'Payment method': 'भुगतान विधि',
  'Prices, stock and the selected shop are revalidated on the server when you place the order.':
      'ऑर्डर करते समय दाम, स्टॉक और चुनी गई दुकान सर्वर पर फिर से जांचे जाते हैं।',
  'Product Choice': 'Product Choice',
  'Product Choice — prices below are the best nearby prices. At checkout, one eligible shop is selected for the complete cart and the final bill is revalidated.':
      'Product Choice — नीचे दिए दाम आस-पास के सबसे अच्छे दाम हैं। चेकआउट पर पूरे कार्ट के लिए एक पात्र दुकान चुनी जाती है और अंतिम बिल फिर से जांचा जाता है।',
  'Product details': 'उत्पाद विवरण',
  'Purana Bazaar': 'Purana Bazaar',
  'Purana Bazaar · Neighbourhood grocery marketplace':
      'Purana Bazaar · मोहल्ले का किराना मार्केटप्लेस',
  'Rate this shop': 'इस दुकान को रेट करें',
  'Razorpay keys are not configured, so this payment is simulated.':
      'Razorpay कुंजियाँ कॉन्फ़िगर नहीं हैं, इसलिए यह भुगतान सिम्युलेटेड है।',
  'Razorpay securely processes the payment. Purana Bazaar never stores your card details.':
      'Razorpay सुरक्षित रूप से भुगतान प्रोसेस करता है। Purana Bazaar आपकी कार्ड जानकारी कभी संग्रहीत नहीं करता।',
  'Razorpay test checkout': 'Razorpay टेस्ट चेकआउट',
  'Register your shop': 'अपनी दुकान रजिस्टर करें',
  'Reserved stock will be restored for the customer.':
      'आरक्षित स्टॉक ग्राहक के लिए बहाल कर दिया जाएगा।',
  'Search milk, atta, fruits and more…': 'दूध, आटा, फल और बहुत कुछ खोजें…',
  'Shop Choice': 'दुकान चुनें',
  'Shop approvals': 'दुकान स्वीकृतियाँ',
  'Shop details': 'दुकान विवरण',
  'Shop inventory': 'दुकान इन्वेंटरी',
  'Shop orders': 'दुकान के ऑर्डर',
  'Shop category': 'दुकान की श्रेणी',
  'Shops considered': 'विचार की गई दुकानें',
  'Sign in to continue shopping.': 'खरीदारी जारी रखने के लिए साइन इन करें।',
  'Some items no longer have enough stock. Adjust quantities before checkout.':
      'कुछ सामान का स्टॉक अब पर्याप्त नहीं है। चेकआउट से पहले मात्रा ठीक करें।',
  'The customer will see this order as cancelled and reserved stock will be returned to the shop.':
      'ग्राहक को यह ऑर्डर रद्द दिखेगा और आरक्षित स्टॉक दुकान को लौटा दिया जाएगा।',
  'The shop will be notified and any reserved stock will be restored.':
      'दुकान को सूचित किया जाएगा और आरक्षित स्टॉक बहाल कर दिया जाएगा।',
  'This shop is outside its delivery radius for your current address. Checkout will be blocked.':
      'यह दुकान आपके वर्तमान पते के डिलीवरी दायरे से बाहर है। चेकआउट रोका जाएगा।',
  'Tip: the demo stores are around Vijay Nagar, Indore. Keep these coordinates to test nearby shop selection.':
      'सुझाव: डेमो दुकानें इंदौर के विजय नगर के आस-पास हैं। आस-पास की दुकान चुनना जांचने के लिए ये निर्देशांक रखें।',
  'TRY A DEMO ACCOUNT': 'डेमो खाता आज़माएं',
  'Two ways to shop': 'खरीदारी के दो तरीके',
  'Unavailable products': 'अनुपलब्ध उत्पाद',
  'Validating shop selection, stock and delivery radius…':
      'दुकान चयन, स्टॉक और डिलीवरी दायरा जांचा जा रहा है…',
  'We find the nearest shop with every item in stock. Your order is never split.':
      'हम हर सामान उपलब्ध कराने वाली सबसे निकट की दुकान ढूंढते हैं। आपका ऑर्डर कभी बांटा नहीं जाता।',
  'We use your address to find eligible shops and calculate the nearest-shop delivery.':
      'हम आपके पते से पात्र दुकानें ढूंढते हैं और निकटतम दुकान से डिलीवरी की गणना करते हैं।',
  'Welcome back': 'वापसी पर स्वागत है',
  'Welcome to Purana Bazaar': 'Purana Bazaar में आपका स्वागत है',
  'YOUR SHOP': 'आपकी दुकान',
  'You can review a shop only after a delivered order from it.':
      'किसी दुकान से डिलीवर हुए ऑर्डर के बाद ही आप उसकी समीक्षा कर सकते हैं।',
  'You choose the shop': 'दुकान आप चुनते हैं',
  'You unlocked free delivery.': 'आपको मुफ़्त डिलीवरी मिल गई।',
  'You will need to sign in again to manage your shop.':
      'अपनी दुकान प्रबंधित करने के लिए आपको दोबारा साइन इन करना होगा।',
  'Your bazaar starts here.': 'आपका बाज़ार यहीं से शुरू होता है।',
  'Your cart': 'आपका कार्ट',
  'Your cart and selected address will be cleared from this device.':
      'आपका कार्ट और चुना गया पता इस डिवाइस से हटा दिया जाएगा।',
  'Your cart stays with this shop. We only show distance and delivery eligibility.':
      'आपका कार्ट इसी दुकान के साथ रहेगा। हम केवल दूरी और डिलीवरी पात्रता दिखाते हैं।',
  'Your neighbourhood, delivered': 'आपका मोहल्ला, घर तक',
  'Your refund has been initiated and usually reaches your account within 5–7 working days.':
      'आपका रिफ़ंड शुरू कर दिया गया है और आमतौर पर 5–7 कार्यदिवसों में आपके खाते में पहुँच जाता है।',
  'Your shop will remain hidden from customers until approved.':
      'स्वीकृति तक आपकी दुकान ग्राहकों से छिपी रहेगी।',
  'inclusive of all taxes': 'सभी करों सहित',
  'Your order is now with': 'आपका ऑर्डर अब यहाँ है',
  'You will pay': 'आप भुगतान करेंगे',
  'on delivery': 'डिलीवरी पर',
  'Currently unavailable': 'अभी उपलब्ध नहीं',
  'Unavailable': 'अनुपलब्ध',
  'Ready from local stock': 'स्थानीय स्टॉक से तैयार',
  'Try another nearby product': 'आस-पास कोई दूसरा उत्पाद आज़माएं',
  'Set a delivery address to see shops': 'दुकानें देखने के लिए डिलीवरी पता सेट करें',
  'Set your delivery location': 'अपना डिलीवरी स्थान सेट करें',
  'Validate again': 'फिर से जांचें',
  'Change address': 'पता बदलें',
  'Groceries from shops\njust around the corner.':
      'आस-पास की दुकानों से\nकिराना।',
  'Delivered from a shop\nnear your home.':
      'आपके घर के पास की\nदुकान से डिलीवरी।',
  'Delivered from a shop\nnear you.':
      'आपके पास की दुकान\nसे डिलीवरी।',
  'Best shop found': 'सबसे अच्छी दुकान मिल गई',
  'No eligible shop': 'कोई पात्र दुकान नहीं',
  'No nearby shop can fulfil the complete cart right now.':
      'अभी आस-पास कोई दुकान पूरा कार्ट पूरा नहीं कर सकती।',
  'No nearby shop can fulfil the complete cart.':
      'आस-पास कोई दुकान पूरा कार्ट पूरा नहीं कर सकती।',
  'This shop can fulfil your complete cart without splitting the order.':
      'यह दुकान बिना ऑर्डर बांटे आपका पूरा कार्ट पूरा कर सकती है।',
  'One shop will fulfil your complete cart':
      'एक ही दुकान आपका पूरा कार्ट पूरा करेगी',
  'We never split an order across shops':
      'हम ऑर्डर को कभी अलग-अलग दुकानों में नहीं बांटते',
  'Add a few products first so we can find a shop.':
      'पहले कुछ उत्पाद जोड़ें ताकि हम दुकान ढूंढ सकें।',
  'Add a delivery address to continue': 'जारी रखने के लिए डिलीवरी पता जोड़ें',
  'Place COD order': 'COD ऑर्डर करें',
  'Pay': 'भुगतान करें',
  'Opening secure checkout…': 'सुरक्षित चेकआउट खुल रहा है…',
  'Payment cancelled. You can retry any time.':
      'भुगतान रद्द हुआ। आप कभी भी फिर कोशिश कर सकते हैं।',
  'Payment cancelled. Your order is saved — you can pay from Orders.':
      'भुगतान रद्द हुआ। आपका ऑर्डर सहेजा गया है — आप ऑर्डर से भुगतान कर सकते हैं।',
  'Payment successful. Your order is confirmed.':
      'भुगतान सफल। आपके ऑर्डर की पुष्टि हो गई।',
  'Order cancelled and stock restored.': 'ऑर्डर रद्द और स्टॉक बहाल।',
  'Please provide a cancellation reason.': 'कृपया रद्द करने का कारण दें।',
  'Please provide a reason.': 'कृपया कारण दें।',
  'Order is reserved. Complete the payment to confirm it.': 'ऑर्डर आरक्षित है। पुष्टि के लिए भुगतान पूरा करें।',
  'Unpaid orders are released automatically after 2 hours.':
      'बिना भुगतान वाले ऑर्डर 2 घंटे बाद अपने आप छोड़ दिए जाते हैं।',
  'This order is no longer active. Any reserved stock has been restored.':
      'यह ऑर्डर अब सक्रिय नहीं है। आरक्षित स्टॉक बहाल कर दिया गया है।',
  'Order cancelled': 'ऑर्डर रद्द हुआ',
  'Order rejected': 'ऑर्डर अस्वीकृत',
  'Payment failed': 'भुगतान विफल',
  'Payment pending': 'भुगतान लंबित',
  'Cash on Delivery': 'कैश ऑन डिलीवरी',
  'Online payment': 'ऑनलाइन भुगतान',
  'Collected by the delivery partner': 'डिलीवरी पार्टनर द्वारा लिया गया',
  'Eligible': 'पात्र',
  'Not eligible': 'पात्र नहीं',
  'Order placed': 'ऑर्डर किया गया',
  'Accepted by shop': 'दुकान ने स्वीकार किया',
  'Being packed': 'पैक किया जा रहा है',
  'Out for delivery': 'डिलीवरी के लिए निकला',
  'Delivered': 'डिलीवर हो गया',
  'Awaiting payment': 'भुगतान प्रतीक्षित',
  'Ready for pickup': 'पिकअप के लिए तैयार',
  'No further updates are available for this delivery.':
      'इस डिलीवरी के लिए और कोई अपडेट नहीं है।',
  'No further status changes are available for this order.':
      'इस ऑर्डर के लिए और कोई स्थिति बदलाव उपलब्ध नहीं है।',
  'Out of range': 'दायरे से बाहर',
  '0.5–50 km': '0.5–50 किमी',
  '5–240': '5–240',

  // ---------------------------------------------------------------------------
  // Cart and checkout
  // ---------------------------------------------------------------------------
  'Estimated delivery': 'अनुमानित डिलीवरी',
  'Estimated total': 'अनुमानित कुल',
  'Item subtotal': 'सामान का उप-योग',
  'Subtotal': 'उप-योग',
  'Total': 'कुल',
  'Method': 'विधि',
  'Phone': 'फ़ोन',
  'Address': 'पता',
  'Change payment method': 'भुगतान विधि बदलें',
  'Delivery partner will collect payment': 'डिलीवरी पार्टनर भुगतान लेगा',
  'Pay online securely': 'सुरक्षित ऑनलाइन भुगतान करें',
  'Order summary': 'ऑर्डर सारांश',
  'Review your order': 'अपना ऑर्डर देखें',
  'Place order': 'ऑर्डर करें',
  'Placing order…': 'ऑर्डर किया जा रहा है…',
  'Proceed to pay': 'भुगतान के लिए आगे बढ़ें',
  'Order total': 'ऑर्डर कुल',
  'Items total': 'सामान का कुल',
  'You saved': 'आपने बचाए',

  // ---------------------------------------------------------------------------
  // Profile / account
  // ---------------------------------------------------------------------------
  'YOUR ACCOUNT': 'आपका खाता',
  'Saved addresses': 'सहेजे गए पते',
  'Home, office and delivery locations': 'घर, ऑफ़िस और डिलीवरी स्थान',
  'Track, cancel or review past orders': 'पुराने ऑर्डर ट्रैक करें, रद्द करें या समीक्षा करें',
  'Order updates, payments and alerts': 'ऑर्डर अपडेट, भुगतान और सूचनाएं',
  'Allow push notifications': 'पुश सूचनाएं अनुमत करें',
  'Push notifications': 'पुश सूचनाएं',
  'Enable push notifications': 'पुश सूचनाएं चालू करें',
  'Blocked in this browser or device': 'इस ब्राउज़र या डिवाइस में ब्लॉक है',
  'Enabled on this device': 'इस डिवाइस पर चालू है',
  'Push notifications are blocked in this browser. Enable them in site settings to get order alerts.':
      'इस ब्राउज़र में पुश सूचनाएं ब्लॉक हैं। ऑर्डर अलर्ट पाने के लिए साइट सेटिंग्स में इन्हें चालू करें।',
  'Push notifications keep you updated even when the app is closed.':
      'ऐप बंद होने पर भी पुश सूचनाएं आपको अपडेट रखती हैं।',
  'Products you saved for later': 'बाद के लिए सहेजे गए उत्पाद',
  'ABOUT': 'परिचय',
  'How Purana Bazaar works': 'Purana Bazaar कैसे काम करता है',
  'Product Choice and Shop Choice explained': 'Product Choice और Shop Choice की जानकारी',
  'Delivery, cancellations and stock questions': 'डिलीवरी, रद्दीकरण और स्टॉक से जुड़े सवाल',
  'GENERAL': 'सामान्य',
  'Language': 'भाषा',
  'App language': 'ऐप की भाषा',
  'Choose the language used across the app': 'ऐप में इस्तेमाल होने वाली भाषा चुनें',
  'Choose language': 'भाषा चुनें',
  'English': 'English',
  'हिन्दी': 'हिन्दी',
  'Your language preference is saved on this device.':
      'आपकी भाषा पसंद इस डिवाइस पर सहेजी जाती है।',
  'Server-verified': 'सर्वर से सत्यापित',
  'Shop selection, prices, delivery fees, stock validation and stock updates happen on the server inside a transaction. Client prices are never trusted.':
      'दुकान चयन, दाम, डिलीवरी शुल्क, स्टॉक सत्यापन और स्टॉक अपडेट सर्वर पर एक ट्रांज़ैक्शन में होते हैं। क्लाइंट के दाम पर कभी भरोसा नहीं किया जाता।',
  'Add products from the marketplace. At checkout the backend evaluates approved, active shops within their delivery radius, checks complete stock, and chooses the nearest shop that can fulfil the entire cart. Orders are never split.':
      'मार्केटप्लेस से उत्पाद जोड़ें। चेकआउट पर बैकएंड स्वीकृत, सक्रिय दुकानों को उनके डिलीवरी दायरे में जांचता है, पूरा स्टॉक देखता है और वह निकटतम दुकान चुनता है जो पूरा कार्ट पूरा कर सके। ऑर्डर कभी नहीं बांटे जाते।',
  'Pick a shop first. Browsing and checkout use only that shop’s inventory. Your cart is locked to that shop, and mixed-shop carts are rejected.':
      'पहले दुकान चुनें। ब्राउज़िंग और चेकआउट केवल उसी दुकान की इन्वेंटरी इस्तेमाल करते हैं। आपका कार्ट उसी दुकान से बंधा रहता है और मिली-जुली दुकानों वाले कार्ट अस्वीकार किए जाते हैं।',

  // ---------------------------------------------------------------------------
  // Forms and placeholders
  // ---------------------------------------------------------------------------
  '1 kg, 500 g…': '1 किलो, 500 ग्राम…',
  'At least 8 characters': 'कम से कम 8 अक्षर',
  'Available quantity': 'उपलब्ध मात्रा',
  'Brand': 'ब्रांड',
  'Category': 'श्रेणी',
  'Category name': 'श्रेणी का नाम',
  'City': 'शहर',
  'Delivery radius (km)': 'डिलीवरी दायरा (किमी)',
  'Description': 'विवरण',
  'Display order': 'प्रदर्शन क्रम',
  'ETA (min)': 'अनुमानित समय (मिनट)',
  'Email address': 'ईमेल पता',
  'Full name': 'पूरा नाम',
  'Full shop address': 'दुकान का पूरा पता',
  'Home, Office, Parents…': 'घर, ऑफ़िस, माता-पिता…',
  'House / street / area': 'मकान / गली / इलाका',
  'How was your experience?': 'आपका अनुभव कैसा रहा?',
  'Image URL': 'छवि URL',
  'Label': 'लेबल',
  'Latitude': 'अक्षांश',
  'Longitude': 'देशांतर',
  'Lower numbers appear first.': 'छोटे नंबर पहले दिखते हैं।',
  'Minimum 0.5 km, maximum 50 km': 'कम से कम 0.5 किमी, अधिकतम 50 किमी',
  'PIN code': 'पिन कोड',
  'Password': 'पासवर्ड',
  'Phone number': 'फ़ोन नंबर',
  'Phone number (optional)': 'फ़ोन नंबर (वैकल्पिक)',
  'Product name': 'उत्पाद का नाम',
  'Radius (km)': 'दायरा (किमी)',
  'Reason': 'कारण',
  'Reason (optional)': 'कारण (वैकल्पिक)',
  'Search a shop, area or category…': 'दुकान, इलाका या श्रेणी खोजें…',
  'Search catalog products…': 'कैटलॉग उत्पाद खोजें…',
  'Search name, email or phone…': 'नाम, ईमेल या फ़ोन खोजें…',
  'Search products, brands or categories…': 'उत्पाद, ब्रांड या श्रेणी खोजें…',
  'Search shops, owners or addresses…': 'दुकानें, मालिक या पते खोजें…',
  'Selling price (₹)': 'बिक्री मूल्य (₹)',
  'Share your experience (optional)': 'अपना अनुभव साझा करें (वैकल्पिक)',
  'Shop name': 'दुकान का नाम',
  'Shop phone': 'दुकान का फ़ोन',
  'Shop phone (optional)': 'दुकान का फ़ोन (वैकल्पिक)',
  'Short description': 'संक्षिप्त विवरण',
  'State': 'राज्य',
  'Unit / pack size': 'इकाई / पैक साइज़',
  'Use at least 8 characters': 'कम से कम 8 अक्षर इस्तेमाल करें',
  'Why is this order being cancelled?': 'यह ऑर्डर क्यों रद्द किया जा रहा है?',
  'Your full name': 'आपका पूरा नाम',
  'e.g. Item unavailable': 'जैसे: सामान उपलब्ध नहीं',
  'e.g. Ordered by mistake': 'जैसे: गलती से ऑर्डर हो गया',
  'e.g. Ring the bell, leave at the door…': 'जैसे: घंटी बजाएं, दरवाज़े पर छोड़ दें…',

  // ---------------------------------------------------------------------------
  // Validation messages
  // ---------------------------------------------------------------------------
  'Enter 0 or more': '0 या अधिक दर्ज करें',
  'Enter 0–100000': '0–100000 दर्ज करें',
  'Enter a number': 'संख्या दर्ज करें',
  'Enter a radius between 0.5 and 50': '0.5 से 50 के बीच दायरा दर्ज करें',
  'Enter a valid PIN code': 'वैध पिन कोड दर्ज करें',
  'Enter a valid email': 'वैध ईमेल दर्ज करें',
  'Enter a valid price': 'वैध मूल्य दर्ज करें',
  'Enter your email address': 'अपना ईमेल पता दर्ज करें',
  'Enter your full name': 'अपना पूरा नाम दर्ज करें',
  'Enter your name': 'अपना नाम दर्ज करें',
  'Enter your password': 'अपना पासवर्ड दर्ज करें',
  'Password must be at least 8 characters': 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए',
  'Enter a name': 'नाम दर्ज करें',
  'Enter a description': 'विवरण दर्ज करें',
  'Enter a category name': 'श्रेणी का नाम दर्ज करें',
  'Enter a price': 'मूल्य दर्ज करें',
  'Enter stock quantity': 'स्टॉक मात्रा दर्ज करें',
  'Enter a shop name': 'दुकान का नाम दर्ज करें',
  'Enter your shop name': 'अपनी दुकान का नाम दर्ज करें',
  'Enter a city': 'शहर दर्ज करें',
  'Enter a state': 'राज्य दर्ज करें',
  'Enter a phone number': 'फ़ोन नंबर दर्ज करें',
  'Enter a valid phone number': 'वैध फ़ोन नंबर दर्ज करें',
  'Enter a valid quantity': 'वैध मात्रा दर्ज करें',
  'Enter the full address': 'पूरा पता दर्ज करें',
  'Enter a label': 'लेबल दर्ज करें',
  'Enter a valid latitude': 'वैध अक्षांश दर्ज करें',
  'Enter a valid longitude': 'वैध देशांतर दर्ज करें',
  'Enter a valid shop phone': 'वैध दुकान फ़ोन दर्ज करें',
  'Enter a reason': 'कारण दर्ज करें',
  'Enter an email address': 'ईमेल पता दर्ज करें',
  'Enter a password': 'पासवर्ड दर्ज करें',
  'This field is required': 'यह फ़ील्ड ज़रूरी है',

  // ---------------------------------------------------------------------------
  // Status labels
  // ---------------------------------------------------------------------------
  'PENDING': 'लंबित',
  'PENDING_APPROVAL': 'स्वीकृति लंबित',
  'PAYMENT_PENDING': 'भुगतान लंबित',
  'PENDING APPROVAL': 'स्वीकृति लंबित',
  'PAYMENT PENDING': 'भुगतान लंबित',
  'APPROVED': 'स्वीकृत',
  'ACTIVE': 'सक्रिय',
  'ACCEPTED': 'स्वीकृत',
  'PREPARING': 'तैयार हो रहा है',
  'READY_FOR_PICKUP': 'पिकअप के लिए तैयार',
  'READY FOR PICKUP': 'पिकअप के लिए तैयार',
  'OUT_FOR_DELIVERY': 'डिलीवरी के लिए निकला',
  'OUT FOR DELIVERY': 'डिलीवरी के लिए निकला',
  'DELIVERED': 'डिलीवर हो गया',
  'CANCELLED': 'रद्द',
  'REJECTED': 'अस्वीकृत',
  'REFUNDED': 'रिफ़ंड हो गया',
  'PAID': 'भुगतान हो गया',
  'FAILED': 'विफल',
  'PAYMENT_FAILED': 'भुगतान विफल',
  'PAYMENT FAILED': 'भुगतान विफल',
  'SUSPENDED': 'निलंबित',
  'TEMPORARILY_CLOSED': 'अस्थायी रूप से बंद',
  'TEMPORARILY CLOSED': 'अस्थायी रूप से बंद',
  'COMPLETED': 'पूर्ण',
  'COD': 'COD',

  // ---------------------------------------------------------------------------
  // Dialogs, empty states and messages
  // ---------------------------------------------------------------------------
  'Address removed.': 'पता हटा दिया गया।',
  'Cart cleared.': 'कार्ट खाली कर दिया गया।',
  'Category deactivated.': 'श्रेणी निष्क्रिय कर दी गई।',
  'Choose a delivery address first.': 'पहले डिलीवरी पता चुनें।',
  'Could not create your account.': 'आपका खाता नहीं बन सका।',
  'Could not register your shop.': 'आपकी दुकान रजिस्टर नहीं हो सकी।',
  'Could not sign in. Please try again.': 'साइन इन नहीं हो सका। कृपया फिर कोशिश करें।',
  'Create a category before adding products.': 'उत्पाद जोड़ने से पहले श्रेणी बनाएं।',
  'Default address updated.': 'डिफ़ॉल्ट पता अपडेट हो गया।',
  'Every active catalog product is already listed for your shop.':
      'हर सक्रिय कैटलॉग उत्पाद पहले से आपकी दुकान में सूचीबद्ध है।',
  'Listing removed.': 'लिस्टिंग हटा दी गई।',
  'No eligible shop can fulfil your cart.': 'कोई पात्र दुकान आपका कार्ट पूरा नहीं कर सकती।',
  'Product deactivated.': 'उत्पाद निष्क्रिय कर दिया गया।',
  'Profile updated.': 'प्रोफ़ाइल अपडेट हो गई।',
  'Removed from wishlist.': 'पसंदीदा से हटा दिया गया।',
  'Shop details updated.': 'दुकान का विवरण अपडेट हो गया।',
  'Shop submitted for approval. You can prepare inventory while you wait.':
      'दुकान स्वीकृति के लिए भेज दी गई। इंतज़ार के दौरान आप इन्वेंटरी तैयार कर सकते हैं।',
  'Thanks for reviewing the shop.': 'दुकान की समीक्षा के लिए धन्यवाद।',
  'Your cart is using Shop Choice. Clear it before switching to Product Choice.':
      'आपका कार्ट Shop Choice इस्तेमाल कर रहा है। Product Choice पर जाने से पहले इसे खाली करें।',
  'Working…': 'काम जारी है…',
  'Loading…': 'लोड हो रहा है…',
  'Loading fresh picks…': 'ताज़ा चीज़ें लोड हो रही हैं…',
  'No results found': 'कोई नतीजा नहीं मिला',
  'Search': 'खोजें',
  'All categories': 'सभी श्रेणियाँ',
  'Filters': 'फ़िल्टर',
  'Sort': 'क्रम',
  'No address selected': 'कोई पता नहीं चुना',
  'Set a delivery address': 'डिलीवरी पता सेट करें',
  'Selected address': 'चुना गया पता',
  'New address': 'नया पता',
  'Edit address': 'पता बदलें',
  'Saved': 'सहेजा गया',
  'Select': 'चुनें',
  'Saving…': 'सहेजा जा रहा है…',
  'Sending…': 'भेजा जा रहा है…',
  'Updating…': 'अपडेट हो रहा है…',
  'Shop': 'दुकान',
  'Shops near you': 'आपके पास की दुकानें',
  'Popular categories': 'लोकप्रिय श्रेणियाँ',
  'Featured shops': 'चुनिंदा दुकानें',
  'Fresh picks': 'ताज़ा चुनाव',
  'Shop by category': 'श्रेणी से खरीदें',
  'See all': 'सभी देखें',
  'Retry loading': 'फिर से लोड करें',
  'Shop now': 'अभी खरीदें',
  'Browse shops': 'दुकानें देखें',
  'Cart is empty': 'कार्ट खाली है',
  'Your cart is empty': 'आपका कार्ट खाली है',
  'Start shopping': 'खरीदारी शुरू करें',
  'Order history': 'ऑर्डर इतिहास',
  'No orders found': 'कोई ऑर्डर नहीं मिला',
  'No notifications yet': 'अभी कोई सूचना नहीं',
  'Notification': 'सूचना',
  'Mark as read': 'पढ़ा हुआ चिह्नित करें',
  'Delete notification': 'सूचना हटाएं',
  'Select language': 'भाषा चुनें',
  'Language changed': 'भाषा बदल गई',
  'Language updated': 'भाषा अपडेट हो गई',
  'Cancel review': 'समीक्षा रद्द करें',
  'Review': 'समीक्षा',
  'Your review': 'आपकी समीक्षा',
  'Write a review': 'समीक्षा लिखें',
  'No reviews yet': 'अभी कोई समीक्षा नहीं',
  'reviews': 'समीक्षाएं',
  'Shop closed': 'दुकान बंद है',
  'Open now': 'अभी खुली है',
  'Closed': 'बंद',
  'OPEN NOW': 'अभी खुली है',
  'CLOSED': 'बंद',
  'Neighbourhood store': 'मोहल्ले की दुकान',
  'Unbranded': 'बिना ब्रांड',
  'New shop': 'नई दुकान',
  'Only': 'केवल',
  'left': 'बचे',
  'Product': 'उत्पाद',
  'Categories': 'श्रेणियाँ',
  'Edit': 'बदलें',
  'Refresh': 'रीफ़्रेश करें',
  'Cart': 'कार्ट',
  'Review all': 'सभी देखें',
  'Explore all': 'सभी देखें',
  'See products': 'उत्पाद देखें',
  'Rate shop': 'दुकान को रेट करें',
  'Browse products': 'उत्पाद देखें',
  'Add your first address': 'अपना पहला पता जोड़ें',
  'Add your first listing': 'अपनी पहली लिस्टिंग जोड़ें',
  'Products': 'उत्पाद',
  'products': 'उत्पाद',
  'items': 'सामान',
  'order': 'ऑर्डर',
  'orders': 'ऑर्डर',
  'shop': 'दुकान',
  'shops': 'दुकानें',
  'min': 'मिनट',
  'km': 'किमी',
  'each': 'प्रति',
  'more': 'और',
  'Free': 'मुफ़्त',
  'Total savings': 'कुल बचत',
  'Delivery partner': 'डिलीवरी पार्टनर',
  'Customer': 'ग्राहक',
  'Customer note': 'ग्राहक नोट',
  'Admin': 'एडमिन',
  'Shop owner': 'दुकान मालिक',
  'Owner': 'मालिक',
  'Owner ID': 'मालिक आईडी',
  'Shop ID': 'दुकान आईडी',
  'Registered': 'पंजीकृत',
  'Closes at': 'बंद होने का समय',
  'Opens at': 'खुलने का समय',
  'Opening hours': 'खुलने का समय',
  'Operational status': 'संचालन स्थिति',
  'Pending orders': 'लंबित ऑर्डर',
  'Delivered orders': 'डिलीवर हो चुके ऑर्डर',
  'Cancelled / rejected': 'रद्द / अस्वीकृत',
  'Suspended shops': 'निलंबित दुकानें',
  'Catalog products': 'कैटलॉग उत्पाद',
  'Active products': 'सक्रिय उत्पाद',
  'Active shops': 'सक्रिय दुकानें',
  'Cancellation': 'रद्दीकरण',
  'Cancellation reason': 'रद्द करने का कारण',
  'Refund': 'रिफ़ंड',
  'Refund status': 'रिफ़ंड स्थिति',
  'Payment status': 'भुगतान स्थिति',
  'Order status': 'ऑर्डर स्थिति',
  'Order number': 'ऑर्डर नंबर',
  'Placed on': 'ऑर्डर तिथि',
  'Placed': 'किया गया',
  'Your order': 'आपका ऑर्डर',
  'Order': 'ऑर्डर',
  'item': 'सामान',
  'unread update': 'अपठित अपडेट',
  'unread updates': 'अपठित अपडेट',

  // ---------------------------------------------------------------------------
  // Screen copy: empty states, loading states and section headings
  // ---------------------------------------------------------------------------
  'Active deliveries': 'सक्रिय डिलीवरी',
  'Add catalog products with your own price and stock. Customers will see this live inventory.':
      'अपने दाम और स्टॉक के साथ कैटलॉग उत्पाद जोड़ें। ग्राहकों को यह लाइव इन्वेंटरी दिखेगी।',
  'Add products from a nearby shop to start a basket. Product Choice picks the shop for you; Shop Choice keeps the shop you select.':
      'बास्केट शुरू करने के लिए आस-पास की दुकान से उत्पाद जोड़ें। Product Choice आपके लिए दुकान चुनता है; Shop Choice आपकी चुनी दुकान रखता है।',
  'Add your home, office or any other address to see nearby shops and delivery times.':
      'आस-पास की दुकानें और डिलीवरी समय देखने के लिए अपना घर, ऑफ़िस या कोई भी पता जोड़ें।',
  'Approval queue': 'स्वीकृति कतार',
  'Best nearby shop for your full cart': 'पूरे कार्ट के लिए सबसे अच्छी आस-पास की दुकान',
  'Both modes are powered by real shop inventory.':
      'दोनों तरीके असली दुकान इन्वेंटरी से चलते हैं।',
  'Comparing nearby shops…': 'आस-पास की दुकानों की तुलना हो रही है…',
  'Could not connect to Purana Bazaar. Is the backend running?':
      'Purana Bazaar से कनेक्ट नहीं हो सका। क्या बैकएंड चल रहा है?',
  'Could not reach the server. Check your connection and try again.':
      'सर्वर तक नहीं पहुँच सके। अपना कनेक्शन जांचें और फिर कोशिश करें।',
  'Create a product or try a different search.':
      'उत्पाद बनाएं या कोई दूसरी खोज आज़माएं।',
  'Create your first category to start building the catalog.':
      'कैटलॉग बनाना शुरू करने के लिए अपनी पहली श्रेणी बनाएं।',
  'Customer reviews': 'ग्राहक समीक्षाएं',
  'Dashboard unavailable': 'डैशबोर्ड उपलब्ध नहीं',
  'Finding ready orders…': 'तैयार ऑर्डर ढूंढे जा रहे हैं…',
  'Finding shops around you…': 'आपके आस-पास की दुकानें ढूंढी जा रही हैं…',
  'Fresh picks near you': 'आपके पास की ताज़ा चीज़ें',
  'Gathering nearby shops…': 'आस-पास की दुकानें जुटाई जा रही हैं…',
  'How do you want to shop?': 'आप कैसे खरीदारी करना चाहते हैं?',
  'Let the owner know what needs fixing': 'मालिक को बताएं कि क्या ठीक करना है',
  'Live prices from approved local shops': 'स्वीकृत स्थानीय दुकानों के लाइव दाम',
  'Live totals across customers and the catalog':
      'ग्राहकों और कैटलॉग के लाइव आंकड़े',
  'Loading catalog…': 'कैटलॉग लोड हो रहा है…',
  'Loading categories…': 'श्रेणियाँ लोड हो रही हैं…',
  'Loading customers…': 'ग्राहक लोड हो रहे हैं…',
  'Loading inventory…': 'इन्वेंटरी लोड हो रही है…',
  'Loading marketplace health…': 'मार्केटप्लेस स्थिति लोड हो रही है…',
  'Loading notifications…': 'सूचनाएं लोड हो रही हैं…',
  'Loading orders…': 'ऑर्डर लोड हो रहे हैं…',
  'Loading shop inventory…': 'दुकान की इन्वेंटरी लोड हो रही है…',
  'Loading shop orders…': 'दुकान के ऑर्डर लोड हो रहे हैं…',
  'Loading shops…': 'दुकानें लोड हो रही हैं…',
  'Loading your addresses…': 'आपके पते लोड हो रहे हैं…',
  'Loading your cart…': 'आपका कार्ट लोड हो रहा है…',
  'Loading your deliveries…': 'आपकी डिलीवरी लोड हो रही है…',
  'Loading your delivery desk…': 'आपका डिलीवरी डेस्क लोड हो रहा है…',
  'Loading your orders…': 'आपके ऑर्डर लोड हो रहे हैं…',
  'Loading your order…': 'आपका ऑर्डर लोड हो रहा है…',
  'Loading your saved products…': 'आपके सहेजे उत्पाद लोड हो रहे हैं…',
  'Loading your shop…': 'आपकी दुकान लोड हो रही है…',
  'Marketplace at a glance': 'मार्केटप्लेस एक नज़र में',
  'No categories yet': 'अभी कोई श्रेणी नहीं',
  'No customers found': 'कोई ग्राहक नहीं मिला',
  'No matching product': 'कोई मिलता उत्पाद नहीं',
  'No orders here': 'यहाँ कोई ऑर्डर नहीं',
  'No pickups waiting': 'कोई पिकअप इंतज़ार में नहीं',
  'No products found': 'कोई उत्पाद नहीं मिला',
  'No products in this category': 'इस श्रेणी में कोई उत्पाद नहीं',
  'No shop found': 'कोई दुकान नहीं मिली',
  'No shop is linked to this owner account.':
      'इस मालिक खाते से कोई दुकान जुड़ी नहीं है।',
  'No shop linked': 'कोई दुकान जुड़ी नहीं',
  'No shops found': 'कोई दुकान नहीं मिली',
  'No shops found here': 'यहाँ कोई दुकान नहीं मिली',
  'Nothing matched': 'कुछ नहीं मिला',
  'Nothing to check out': 'चेकआउट के लिए कुछ नहीं',
  'Order not found': 'ऑर्डर नहीं मिला',
  'Orders appear here as soon as a shop marks them ready for pickup. Pull down to refresh.':
      'दुकान द्वारा पिकअप के लिए तैयार चिह्नित करते ही ऑर्डर यहाँ दिखते हैं। रीफ़्रेश के लिए नीचे खींचें।',
  'Orders matching this status will appear as customers check out.':
      'ग्राहक चेकआउट करते ही इस स्थिति वाले ऑर्डर यहाँ दिखेंगे।',
  'Pay online': 'ऑनलाइन भुगतान करें',
  'Pay the delivery partner when your order arrives.':
      'ऑर्डर आने पर डिलीवरी पार्टनर को भुगतान करें।',
  'Recent orders': 'हाल के ऑर्डर',
  'Reject shop registration?': 'दुकान रजिस्ट्रेशन अस्वीकार करें?',
  'Role not supported': 'भूमिका समर्थित नहीं',
  'Save what you love': 'जो पसंद हो उसे सहेजें',
  'Shop from your favourite store': 'अपनी पसंदीदा दुकान से खरीदें',
  'Suspend this shop?': 'इस दुकान को निलंबित करें?',
  'Tap the heart on any product to keep it here for later. Availability and best prices refresh automatically.':
      'किसी भी उत्पाद पर दिल दबाकर उसे बाद के लिए यहाँ रखें। उपलब्धता और सबसे अच्छे दाम अपने आप रीफ़्रेश होते हैं।',
  'The admin dashboard could not be loaded.':
      'एडमिन डैशबोर्ड लोड नहीं हो सका।',
  'The server took too long to respond. Please try again.':
      'सर्वर ने बहुत समय लिया। कृपया फिर कोशिश करें।',
  'The shop will be hidden from customers': 'दुकान ग्राहकों से छिप जाएगी',
  'This account has a role that this app version does not recognise. Please contact an administrator.':
      'इस खाते की भूमिका इस ऐप संस्करण को मान्य नहीं है। कृपया एडमिन से संपर्क करें।',
  'This order could not be loaded.': 'यह ऑर्डर लोड नहीं हो सका।',
  'Try a different search term or category. New local products are added often.':
      'कोई दूसरा खोज शब्द या श्रेणी आज़माएं। नए स्थानीय उत्पाद अक्सर जोड़े जाते हैं।',
  'Try a different search term.': 'कोई दूसरा खोज शब्द आज़माएं।',
  'Try another area, or check back soon as more neighbourhood shops join the bazaar.':
      'कोई दूसरा इलाका आज़माएं, या जल्द फिर देखें क्योंकि और मोहल्ले की दुकानें बाज़ार से जुड़ रही हैं।',
  'Try another category, or check back after the shop updates its stock.':
      'कोई दूसरी श्रेणी आज़माएं, या दुकान के स्टॉक अपडेट होने के बाद फिर देखें।',
  'Try another name or brand.': 'कोई दूसरा नाम या ब्रांड आज़माएं।',
  'Where should we deliver?': 'हम कहाँ डिलीवरी करें?',
  'Your basket is empty': 'आपकी बास्केट खाली है',
  'Your cart is empty. Add some products before placing an order.':
      'आपका कार्ट खाली है। ऑर्डर करने से पहले कुछ उत्पाद जोड़ें।',
  'Your shelves are empty': 'आपकी अलमारियाँ खाली हैं',
  'Shop approved.': 'दुकान स्वीकृत कर दी गई।',
  'Shop rejected.': 'दुकान अस्वीकृत कर दी गई।',
  'Shop suspended.': 'दुकान निलंबित कर दी गई।',
  'Shop reactivated.': 'दुकान फिर से सक्रिय कर दी गई।',
  'Customer suspended.': 'ग्राहक निलंबित कर दिया गया।',
  'Customer reactivated.': 'ग्राहक फिर से सक्रिय कर दिया गया।',

  // ---------------------------------------------------------------------------
  // Server messages, notifications, quote reasons and seeded catalog copy
  // ---------------------------------------------------------------------------
  'Incorrect email or password.':
      'ईमेल या पासवर्ड गलत है।',
  'An account with this email already exists.':
      'इस ईमेल से खाता पहले से मौजूद है।',
  'This account has been suspended. Please contact support.':
      'यह खाता निलंबित कर दिया गया है। कृपया सहायता टीम से संपर्क करें।',
  'Please sign in to continue.':
      'जारी रखने के लिए कृपया साइन इन करें।',
  'You are not allowed to perform this action.':
      'आपको यह कार्रवाई करने की अनुमति नहीं है।',
  'Your cart is empty.':
      'आपका कार्ट खाली है।',
  'Cart item not found.':
      'कार्ट में यह सामान नहीं मिला।',
  'Quantity must be between 1 and 99.':
      'मात्रा 1 से 99 के बीच होनी चाहिए।',
  'Maximum quantity per item is 99.':
      'प्रति सामान अधिकतम मात्रा 99 है।',
  'This item is no longer available at the shop.':
      'यह सामान अब दुकान पर उपलब्ध नहीं है।',
  'This product is not available at the shop.':
      'यह उत्पाद दुकान पर उपलब्ध नहीं है।',
  'This product is out of stock at this shop.':
      'इस दुकान पर यह उत्पाद स्टॉक में नहीं है।',
  'No nearby shop currently has this product in stock.':
      'आस-पास की किसी दुकान में अभी यह उत्पाद स्टॉक में नहीं है।',
  'This shop is not accepting orders right now.':
      'यह दुकान अभी ऑर्डर नहीं ले रही है।',
  'This shop is currently closed.':
      'यह दुकान अभी बंद है।',
  'This shop does not offer delivery.':
      'यह दुकान डिलीवरी नहीं करती।',
  'A product with this name and brand already exists. Add it to your inventory instead.':
      'इस नाम और ब्रांड का उत्पाद पहले से मौजूद है। इसके बजाय इसे अपनी इन्वेंटरी में जोड़ें।',
  'A category with this name already exists.':
      'इस नाम की श्रेणी पहले से मौजूद है।',
  'This product is already listed. Edit its price or stock instead.':
      'यह उत्पाद पहले से सूचीबद्ध है। इसके बजाय उसका दाम या स्टॉक बदलें।',
  'Create a new inventory record to list a different product.':
      'किसी दूसरे उत्पाद को सूचीबद्ध करने के लिए नया इन्वेंटरी रिकॉर्ड बनाएं।',
  'Cart item is missing its shop listing.':
      'कार्ट आइटम में दुकान की लिस्टिंग नहीं है।',
  'Cart item is missing a product.':
      'कार्ट आइटम में उत्पाद नहीं है।',
  'A Shop Choice order can only contain products from one shop.':
      'दुकान चुनें ऑर्डर में केवल एक ही दुकान के उत्पाद हो सकते हैं।',
  'Your cart already contains Product Choice items. Clear the cart before switching to Shop Choice.':
      'आपके कार्ट में पहले से Product Choice सामान है। दुकान चुनें पर जाने से पहले कार्ट खाली करें।',
  'Select a shop before checkout.':
      'चेकआउट से पहले दुकान चुनें।',
  'Stock changed while processing your request. Please refresh and try again.':
      'आपका अनुरोध संसाधित होते समय स्टॉक बदल गया। कृपया रीफ़्रेश करके फिर कोशिश करें।',
  'Shop listing not found.':
      'दुकान की लिस्टिंग नहीं मिली।',
  'Shop not found.':
      'दुकान नहीं मिली।',
  'Product not found.':
      'उत्पाद नहीं मिला।',
  'Category not found.':
      'श्रेणी नहीं मिली।',
  'Customer not found.':
      'ग्राहक नहीं मिला।',
  'Order not found.':
      'ऑर्डर नहीं मिला।',
  'Delivery order not found.':
      'डिलीवरी ऑर्डर नहीं मिला।',
  'Inventory item not found.':
      'इन्वेंटरी आइटम नहीं मिला।',
  'Wishlist item not found.':
      'विशलिस्ट आइटम नहीं मिला।',
  'Notification not found.':
      'सूचना नहीं मिली।',
  'Delivery address not found.':
      'डिलीवरी पता नहीं मिला।',
  'Resource not found.':
      'संसाधन नहीं मिला।',
  'This order cannot be cancelled.':
      'यह ऑर्डर रद्द नहीं किया जा सकता।',
  'This order can no longer be cancelled. Please contact the shop.':
      'यह ऑर्डर अब रद्द नहीं हो सकता। कृपया दुकान से संपर्क करें।',
  'This order has already been paid.':
      'इस ऑर्डर का भुगतान हो चुका है।',
  'This order can no longer be paid.':
      'इस ऑर्डर का भुगतान अब नहीं हो सकता।',
  'This order is set to Cash on Delivery.':
      'यह ऑर्डर कैश ऑन डिलीवरी पर सेट है।',
  'This payment does not belong to the order. Please try again.':
      'यह भुगतान इस ऑर्डर का नहीं है। कृपया फिर कोशिश करें।',
  'We could not verify this payment. If money was deducted, please contact support.':
      'हम यह भुगतान सत्यापित नहीं कर सके। यदि पैसे कट गए हैं तो सहायता टीम से संपर्क करें।',
  'Could not confirm the payment with Razorpay. Please try again.':
      'Razorpay के साथ भुगतान की पुष्टि नहीं हो सकी। कृपया फिर कोशिश करें।',
  'Could not start the online payment. Please try again.':
      'ऑनलाइन भुगतान शुरू नहीं हो सका। कृपया फिर कोशिश करें।',
  'Online payments are not configured yet. Please choose Cash on Delivery.':
      'ऑनलाइन भुगतान अभी सेट नहीं है। कृपया कैश ऑन डिलीवरी चुनें।',
  'Razorpay reported that this payment failed. Please try again.':
      'Razorpay ने बताया कि यह भुगतान विफल रहा। कृपया फिर कोशिश करें।',
  'No payment was started for this order.':
      'इस ऑर्डर के लिए कोई भुगतान शुरू नहीं हुआ।',
  'The payment could not be refunded automatically. Please contact support.':
      'भुगतान अपने आप वापस नहीं किया जा सका। कृपया सहायता टीम से संपर्क करें।',
  'Payment was not completed in time.':
      'भुगतान समय पर पूरा नहीं हुआ।',
  'The payment failed.':
      'भुगतान विफल रहा।',
  'Reserved stock was released.':
      'आरक्षित स्टॉक जारी कर दिया गया।',
  'Your shop is not active. Contact the administrator.':
      'आपकी दुकान सक्रिय नहीं है। एडमिन से संपर्क करें।',
  'You can only manage inventory for your own shop.':
      'आप केवल अपनी दुकान की इन्वेंटरी प्रबंधित कर सकते हैं।',
  'You can only manage orders for your own shop.':
      'आप केवल अपनी दुकान के ऑर्डर प्रबंधित कर सकते हैं।',
  'You can only manage your own shop.':
      'आप केवल अपनी दुकान प्रबंधित कर सकते हैं।',
  'You can only update deliveries assigned to you.':
      'आप केवल अपने सौंपे गए डिलीवरी अपडेट कर सकते हैं।',
  'You can review a shop after receiving a delivered order from it.':
      'किसी दुकान से डिलीवर हुआ ऑर्डर मिलने के बाद आप उसकी समीक्षा कर सकते हैं।',
  'Another delivery partner has already accepted this order.':
      'एक अन्य डिलीवरी पार्टनर पहले ही यह ऑर्डर स्वीकार कर चुका है।',
  'This order is not ready for pickup yet.':
      'यह ऑर्डर अभी पिकअप के लिए तैयार नहीं है।',
  'One of the products is no longer available.':
      'इनमें से एक उत्पाद अब उपलब्ध नहीं है।',
  'One of the products is no longer available at this shop. Please refresh your cart.':
      'इस दुकान पर इनमें से एक उत्पाद अब उपलब्ध नहीं है। कृपया अपना कार्ट रीफ़्रेश करें।',
  'The shop is outside its delivery radius for this address.':
      'यह दुकान इस पते के डिलीवरी दायरे से बाहर है।',
  'Add a delivery address or share your location to continue.':
      'जारी रखने के लिए डिलीवरी पता जोड़ें या अपना स्थान साझा करें।',
  'Something went wrong. Please try again.':
      'कुछ गलत हो गया। कृपया फिर कोशिश करें।',
  'The request conflicts with existing data. Please refresh and try again.':
      'अनुरोध मौजूदा डेटा से टकरा रहा है। कृपया रीफ़्रेश करके फिर कोशिश करें।',
  'Please correct the highlighted fields.':
      'कृपया चिह्नित फ़ील्ड ठीक करें।',
  'Unable to compute the Razorpay signature.':
      'Razorpay हस्ताक्षर की गणना नहीं हो सकी।',
  'Sorry! No nearby shop currently has all the products in your cart.':
      'क्षमा करें! आस-पास की किसी दुकान में अभी आपके कार्ट के सभी उत्पाद नहीं हैं।',
  'One item is unavailable in the requested quantity':
      'एक सामान अनुरोधित मात्रा में उपलब्ध नहीं है',
  'Shop is not approved':
      'दुकान स्वीकृत नहीं है',
  'Shop is temporarily closed':
      'दुकान अस्थायी रूप से बंद है',
  'Shop does not offer delivery':
      'दुकान डिलीवरी नहीं करती',
  'Shop is currently closed':
      'दुकान अभी बंद है',
  'Account reactivated':
      'खाता फिर से सक्रिय',
  'Account suspended':
      'खाता निलंबित',
  'Delivery partner assigned':
      'डिलीवरी पार्टनर नियुक्त',
  'Delivered 🎉':
      'डिलीवर हो गया 🎉',
  'New order received':
      'नया ऑर्डर मिला',
  'New paid order':
      'नया भुगतान किया ऑर्डर',
  'Order accepted':
      'ऑर्डर स्वीकार हुआ',
  'Order assigned for delivery':
      'ऑर्डर डिलीवरी के लिए सौंपा गया',
  'Order created – complete payment':
      'ऑर्डर बना – भुगतान पूरा करें',
  'Order delivered':
      'ऑर्डर डिलीवर हुआ',
  'Order expired':
      'ऑर्डर समाप्त',
  'Order placed ✅':
      'ऑर्डर हो गया ✅',
  'Out for delivery 🛵':
      'डिलीवरी के लिए निकला 🛵',
  'Payment successful ✅':
      'भुगतान सफल ✅',
  'Refund initiated':
      'रिफ़ंड शुरू किया गया',
  'Shop approved 🎉':
      'दुकान स्वीकृत 🎉',
  'Shop registration needs attention':
      'दुकान रजिस्ट्रेशन पर ध्यान दें',
  'Shop registration received':
      'दुकान रजिस्ट्रेशन प्राप्त हुआ',
  'Shop suspended':
      'दुकान निलंबित',
  'Welcome to Purana Bazaar 👋':
      'Purana Bazaar में आपका स्वागत है 👋',
  'Your order is being packed':
      'आपका ऑर्डर पैक किया जा रहा है',
  'Cancelled by administrator':
      'एडमिन द्वारा रद्द',
  'Cancelled by customer':
      'ग्राहक द्वारा रद्द',
  'Rejected by shop':
      'दुकान द्वारा अस्वीकृत',
  'Discover fresh groceries from trusted neighbourhood shops. Your orders and delivery updates will appear here.':
      'भरोसेमंद मोहल्ले की दुकानों से ताज़ा किराना खोजें। आपके ऑर्डर और डिलीवरी अपडेट यहाँ दिखेंगे।',
  'Your Purana Bazaar account is active again. Welcome back!':
      'आपका Purana Bazaar खाता फिर से सक्रिय है। वापसी पर स्वागत है!',
  'Your account has been suspended. Please contact support if you believe this is a mistake.':
      'आपका खाता निलंबित कर दिया गया है। यदि आपको लगता है कि यह गलती से हुआ है तो सहायता टीम से संपर्क करें।',
  'Vegetables':
      'सब्ज़ियाँ',
  'Fruits':
      'फल',
  'Dairy & Eggs':
      'डेयरी और अंडे',
  'Bakery':
      'बेकरी',
  'Staples & Grains':
      'मुख्य खाद्य और अनाज',
  'Snacks & Munchies':
      'स्नैक्स और नमकीन',
  'Beverages':
      'पेय',
  'Personal Care':
      'व्यक्तिगत देखभाल',
  'Household Essentials':
      'घरेलू ज़रूरतें',
  'Frozen Foods':
      'फ्रोज़न फूड',
  'Baby Care':
      'बेबी केयर',
  'Fresh vegetables sourced daily':
      'रोज़ ताज़ी सब्ज़ियाँ',
  'Seasonal and everyday fruits':
      'मौसमी और रोज़ के फल',
  'Milk, butter, paneer and eggs':
      'दूध, मक्खन, पनीर और अंडे',
  'Breads, buns and baked treats':
      'ब्रेड, बन और बेक किए स्नैक्स',
  'Atta, rice, dal and cooking oil':
      'आटा, चावल, दाल और खाना पकाने का तेल',
  'Chips, biscuits and namkeen':
      'चिप्स, बिस्किट और नमकीन',
  'Tea, coffee, juices and soft drinks':
      'चाय, कॉफ़ी, जूस और कोल्ड ड्रिंक',
  'Everyday personal care essentials':
      'रोज़ की व्यक्तिगत देखभाल',
  'Cleaning and home care products':
      'सफ़ाई और घर की देखभाल के उत्पाद',
  'Freezer staples, fries and ice creams':
      'फ्रोज़न सामान, फ्राइज़ और आइसक्रीम',
  'Diapers, baby food and gentle care':
      'डायपर, बेबी फूड और कोमल देखभाल',
  'Kirana':
      'किराना',
  'Grocery':
      'किराना',
  'Supermarket':
      'सुपरमार्केट',
  'Fresh Produce':
      'ताज़ी उपज',
};
