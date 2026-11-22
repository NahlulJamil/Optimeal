import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Perataan judul layar auth. Figma memakai rata kiri untuk Login/Registrasi
/// dan rata tengah untuk Verifikasi email.
enum AuthHeaderAlignment { start, center }

/// Kerangka layar autentikasi sesuai Figma "Balomba" (page HiFi Optimeal).
///
/// Struktur: navigation bar 72 px (tombol kembali bulat 40 px), blok brand
/// opsional, judul, deskripsi, lalu isi form. Padding horizontal 32 px sama
/// dengan frame Login/Registrasi/Verifikasi.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.subtitleWidget,
    this.showBrand = false,
    this.headerIcon,
    this.headerTrailing,
    this.alignment = AuthHeaderAlignment.start,
    this.contentTopPadding = 16,
    this.headerGap = 24,
  });

  final String title;
  final String? subtitle;

  /// Alternatif [subtitle] bila perlu teks kaya (mis. email ditebalkan).
  final Widget? subtitleWidget;
  final List<Widget> children;

  /// Blok logo + wordmark "Optimeal" (hanya dipakai layar Login di Figma).
  final bool showBrand;

  /// Ikon di dalam lingkaran hijau muda (layar Verifikasi email).
  final Widget? headerIcon;

  /// Aksi di bawah deskripsi (mis. "Change email").
  final Widget? headerTrailing;

  final AuthHeaderAlignment alignment;
  final double contentTopPadding;
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final centered = alignment == AuthHeaderAlignment.center;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _AuthNavigationBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  32,
                  contentTopPadding,
                  32,
                  48 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showBrand) ...[
                      const _BrandLockup(),
                      const SizedBox(height: 8),
                    ],
                    if (headerIcon != null) ...[
                      Center(child: _HeaderBadge(child: headerIcon!)),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      title,
                      textAlign: textAlign,
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 10),
                    if (subtitleWidget != null)
                      subtitleWidget!
                    else if (subtitle != null)
                      Text(
                        subtitle!,
                        textAlign: textAlign,
                        style: AppTextStyles.body,
                      ),
                    if (headerTrailing != null) ...[
                      const SizedBox(height: 16),
                      Center(child: headerTrailing!),
                    ],
                    SizedBox(height: headerGap),
                    ...children,
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

/// Navigation bar 72 px dengan tombol kembali bulat 40 px (hanya tampil bila
/// layar memang bisa dikembalikan).
class _AuthNavigationBar extends StatelessWidget {
  const _AuthNavigationBar();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Align(
          alignment: Alignment.centerLeft,
          child: canPop
              ? Semantics(
                  button: true,
                  label: 'Back',
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Logo mark + wordmark "Optimeal" (Lora SemiBold 24, primary).
///
/// Figma "Welcome › Frame 5": 105 × 135 dengan padding atas/bawah 20 px,
/// logo 55 × 57, jarak 7 px ke wordmark 31 px.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Image.asset(
              'assets/images/logo_mark.png',
              width: 55,
              height: 57,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 7),
            const Text(
              'Optimeal',
              style: TextStyle(
                fontFamily: AppTextStyles.brandFont,
                fontSize: 24,
                height: 1.3,
                fontVariations: [FontVariation('wght', 600)],
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lingkaran hijau muda berisi ikon (Figma: "Email badge", 88 px).
class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryTint,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// Label kecil di atas input: Inter 14 SemiBold.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.fieldLabel),
    );
  }
}

/// Kotak input putih: tinggi 54, radius 16, border `#EAE6DF`, ikon di kiri.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.enabled = true,
    this.onChanged,
    this.helperText,
    this.hasError = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? helperText;

  /// Menampilkan border merah tanpa pesan bawaan, dipakai saat server menolak
  /// kredensial (Figma "Login — sandi salah").
  final bool hasError;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          validator: validator,
          enabled: enabled,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          autocorrect: false,
          style: AppTextStyles.fieldValue,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppTextStyles.fieldValue.copyWith(
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 18, color: AppColors.textSecondary),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 54,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 54,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            constraints: const BoxConstraints(minHeight: 54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kFieldRadius),
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.border,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kFieldRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kFieldRadius),
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kFieldRadius),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kFieldRadius),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
            errorStyle: AppTextStyles.helper.copyWith(
              color: AppColors.danger,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(helperText!, style: AppTextStyles.helper),
        ],
      ],
    );
  }
}

/// Input password dengan tombol show/hide.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.enabled = true,
    this.hint,
    this.helperText,
    this.hasError = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool enabled;
  final String? hint;
  final String? helperText;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      icon: Icons.lock_outline_rounded,
      obscureText: _hidden,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      enabled: widget.enabled,
      helperText: widget.helperText,
      hasError: widget.hasError,
      onChanged: widget.onChanged,
      suffix: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}

/// Banner error merah lembut (Figma "Password error": `#FFF0ED`, radius 12).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message, this.margin});

  final String message;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.helper.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Teks kecil + tombol untuk pindah antar layar (Figma "Account navigation").
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(question, style: AppTextStyles.linkHint),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action, style: AppTextStyles.link),
          ),
        ],
      ),
    );
  }
}

/// Tautan teks rata kanan/kiri (mis. "Forgot password?").
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.align = MainAxisAlignment.end,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MainAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: align,
      children: [
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            minimumSize: const Size(0, 25),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppTextStyles.link),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu informasi hijau muda (Figma "Delivery guidance", radius 16).
class AuthInfoCard extends StatelessWidget {
  const AuthInfoCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.helper.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol utama layar auth: pill 56 px, Inter 16 Bold (Figma "Primary action").
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: kButtonHeight,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          foregroundColor: AppColors.surface,
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button,
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surface,
                ),
              )
            : Text(label),
      ),
    );
  }
}
