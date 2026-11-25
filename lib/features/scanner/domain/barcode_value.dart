/// Turns what the camera read (EAN/UPC barcode or a QR code) into the product
/// number the Worker looks up (`POST /analyze-barcode`, 8–14 digits).
///
/// Supported:
/// * plain EAN-8 / EAN-13 / UPC-A / UPC-E / GTIN-14 digits;
/// * GS1 Digital Link QR codes, e.g. `https://id.gs1.org/01/08996001600146`;
/// * GS1 element strings, e.g. `(01)08996001600146(17)271231` or
///   `0108996001600146…` (Code 128 / QR on packaging).
///
/// Returns `null` when the code carries no product number (e.g. a QR code
/// with a website or payment link).
String? productCodeFromScan(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final digitsOnly = value.replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'^\d{8,14}$').hasMatch(digitsOnly)) return digitsOnly;

  // GS1 Digital Link: …/01/<GTIN>…
  final link = RegExp(r'/01/(\d{8,14})(?:[/?#]|$)').firstMatch(value);
  if (link != null) return link.group(1);

  // GS1 element string with Application Identifier 01 (GTIN-14).
  final element = RegExp(r'^(?:\]C1|\]Q3|\]d2)?\(?01\)?(\d{14})')
      .firstMatch(value.replaceAll('\u001d', ''));
  if (element != null) return element.group(1);

  return null;
}
