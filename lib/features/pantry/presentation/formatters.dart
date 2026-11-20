import 'package:intl/intl.dart';

/// Date formats from Contracts §1. Storage stays ISO-8601; this is display only.
///
/// Language switching is owned by Developer 1. `en_US` symbols are built into
/// `intl`; the `id` format needs `initializeDateFormatting('id')` at startup,
/// which belongs to Developer 1's localization setup.
String formatDisplayDate(DateTime date, {String language = 'en'}) {
  return language == 'id'
      ? DateFormat('d MMM yyyy', 'id').format(date.toLocal())
      : DateFormat('MMM d, yyyy', 'en_US').format(date.toLocal());
}
