import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Isi ringkas Syarat & Ketentuan (PRD §3.1, v1.10).
///
/// Ditampilkan di bottom sheet agar tautan pada checkbox persetujuan tidak
/// menuju halaman kosong. Teks sengaja ringkas dan faktual.
const String kTermsBody =
    'Optimeal helps you keep track of the ingredients in your pantry, estimate '
    'how long they stay fresh, and get recipe ideas.\n\n'
    '1. You need an account to use Optimeal. Keep your password private; you '
    'are responsible for activity on your account.\n\n'
    '2. Ingredient and recipe data are stored in your own account. Shelf-life '
    'estimates and recipe suggestions are produced by an AI service and are '
    'estimates only — always check food yourself before eating it.\n\n'
    '3. Food photos are stored on your device only and are never uploaded to '
    'the AI service.\n\n'
    '4. Do not use Optimeal for medical, allergy, or food-safety advice. When '
    'in doubt about a food item, throw it away.\n\n'
    '5. We may update these terms as the app develops. Continued use after an '
    'update means you accept the current version.';

/// Isi ringkas Kebijakan Privasi (PRD §3.1, v1.10).
const String kPrivacyBody =
    'What we store\n'
    '• Account data: name, email address, and profile settings.\n'
    '• Pantry, favourites, and notification data linked to your account.\n'
    '• Food photos, kept only in your device storage.\n\n'
    'How we use it\n'
    'Data is used only to run the features you see in the app: your pantry '
    'list, shelf-life reminders, and recipe suggestions.\n\n'
    'What we share\n'
    'Barcode values, uploaded food photos, and pantry summaries are sent to the '
    'AI service through our own proxy to produce analysis and recipes. No '
    'advertising networks or third-party analytics are used.\n\n'
    'Your control\n'
    'You can edit or delete any pantry item, sign out at any time, and request '
    'account deletion from the Profile menu.\n\n'
    'Security\n'
    'Access to your data requires an authenticated session, and security rules '
    'restrict every account to its own records.';

/// Menampilkan isi dokumen legal dalam bottom sheet.
Future<void> showLegalSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: AppTextStyles.sectionTitle),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
                  child: Text(
                    body,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  32,
                  8,
                  32,
                  24 + MediaQuery.paddingOf(sheetContext).bottom,
                ),
                child: AuthSheetCloseButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Tombol tutup bottom sheet (pill, gaya sama dengan tombol utama).
class AuthSheetCloseButton extends StatelessWidget {
  const AuthSheetCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button.copyWith(fontSize: 15),
        ),
        child: const Text('Close'),
      ),
    );
  }
}
