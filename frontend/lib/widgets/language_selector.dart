import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/localization.dart';
import '../state/language_provider.dart';

/// Opens the language picker (English / हिन्दी).
Future<void> showLanguagePicker(BuildContext context) async {
  final provider = context.read<LanguageProvider>();
  final current = provider.language;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      void choose(AppLanguage language) {
        provider.setLanguage(language);
        Navigator.pop(sheetContext);
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              AppText(
                'Choose language',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              AppText(
                'Your language preference is saved on this device.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              _LanguageOption(
                flag: '🇬🇧',
                title: 'English',
                subtitle: 'English',
                selected: current == AppLanguage.english,
                onTap: () => choose(AppLanguage.english),
              ),
              const SizedBox(height: 8),
              _LanguageOption(
                flag: '🇮🇳',
                title: 'हिन्दी',
                subtitle: 'Hindi',
                selected: current == AppLanguage.hindi,
                onTap: () => choose(AppLanguage.hindi),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.paleMint : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              AppText(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppText(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Globe action for app bars.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Language'),
      onPressed: () => showLanguagePicker(context),
      icon: Icon(
        Icons.translate_rounded,
        color: color,
        semanticLabel: context.tr('Language'),
      ),
    );
  }
}

/// List tile used inside the profile screen.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.paleMint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.translate_rounded,
            color: AppColors.green, size: 20),
      ),
      title: AppText(
        'App language',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      subtitle: AppText(
        language == AppLanguage.hindi ? 'हिन्दी' : 'English',
        style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: () => showLanguagePicker(context),
    );
  }
}
