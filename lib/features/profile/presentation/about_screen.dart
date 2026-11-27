import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_widgets.dart';

/// Profile → About (Figma "About").
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Optimeal', style: AppTextStyles.heading),
                    SizedBox(height: 8),
                    Text(
                      'Smart Food Management, Zero Food Waste',
                      style: AppTextStyles.body,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'About Optimeal',
                      style: TextStyle(
                        fontFamily: AppTextStyles.uiFont,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Optimeal is an AI-powered smart food management '
                      'application designed to help households, students, and '
                      'culinary businesses minimize food waste. By tracking '
                      'ingredient freshness, predicting shelf life, and '
                      'recommending creative recipes from what you already '
                      'have, Optimeal makes sustainable living effortless and '
                      'budget-friendly.',
                      style: AppTextStyles.body,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Features',
                      style: TextStyle(
                        fontFamily: AppTextStyles.uiFont,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 14),
                    _FeatureBullet(
                      'Smart Inventory Tracking - Keep track of your pantry '
                      'and fridge items in one place.',
                    ),
                    SizedBox(height: 8),
                    _FeatureBullet(
                      'AI Shelf-Life Prediction - Get timely expiry alerts '
                      'before your ingredients go to waste.',
                    ),
                    SizedBox(height: 8),
                    _FeatureBullet(
                      'Zero-Waste Recipe Generator - Discover personalized '
                      'recipes based on ingredients you need to use first.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, right: 10),
          child: Text('•', style: AppTextStyles.body),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
