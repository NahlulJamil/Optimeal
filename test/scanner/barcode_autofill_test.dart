import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/scanner/application/scanner_providers.dart';
import 'package:optimeal/features/scanner/data/ai_client.dart';
import 'package:optimeal/features/scanner/domain/barcode_value.dart';

void main() {
  group('productCodeFromScan', () {
    test('keeps plain EAN / UPC digits', () {
      expect(productCodeFromScan('8996001600146'), '8996001600146');
      expect(productCodeFromScan(' 089686010947 '), '089686010947');
      expect(productCodeFromScan('96385074'), '96385074');
    });

    test('reads the GTIN from a GS1 Digital Link QR code', () {
      expect(
        productCodeFromScan('https://id.gs1.org/01/08996001600146'),
        '08996001600146',
      );
      expect(
        productCodeFromScan(
          'https://example.com/01/08996001600146/10/ABC?17=271231',
        ),
        '08996001600146',
      );
    });

    test('reads the GTIN from a GS1 element string', () {
      expect(
        productCodeFromScan('(01)08996001600146(17)271231'),
        '08996001600146',
      );
      expect(productCodeFromScan('010899600160014617271231'), '08996001600146');
    });

    test('rejects codes without a product number', () {
      expect(productCodeFromScan('https://optimeal.app/promo'), isNull);
      expect(productCodeFromScan('ABC-123'), isNull);
      expect(productCodeFromScan('1234'), isNull);
      expect(productCodeFromScan(''), isNull);
    });
  });

  group('entryFromAnalysis for a scanned package', () {
    FoodAnalysis analysis({
      String category = 'Snacks & Beverages',
      Object? shelfLife,
      String? packageSize = '350 ml',
    }) => FoodAnalysis.parse({
      'name': 'Teh Pucuk Harum Jasmine 350 ml',
      'category': category,
      'confidence': 0.7,
      'packageSize': packageSize,
      'brand': 'Mayora',
      'shelfLifeDays': shelfLife,
    });

    test('fills name, category, size and a Pantry location', () {
      final entry = entryFromAnalysis(
        analysis(
          shelfLife: {'room_temperature': 270, 'fridge': 300, 'freezer': 365},
        ),
        fromBarcode: true,
        today: DateTime(2026, 11, 25),
      );
      expect(entry.name, 'Teh Pucuk Harum Jasmine 350 ml');
      expect(entry.category, 'Snacks & Beverages');
      expect(entry.quantityText, '350 ml');
      expect(entry.location, StorageLocation.roomTemperature);
      expect(entry.shelfLifeDays, 270);
      expect(entry.validate(), isNull);
    });

    test('without an AI estimate the catalog fallback is used', () {
      final entry = entryFromAnalysis(analysis(), fromBarcode: true);
      expect(entry.estimate, isNull);
      // Fallback catalog: Snacks & Beverages, room temperature = 90 days.
      expect(entry.shelfLifeDays, 90);
      expect(entry.validate(), isNull);
    });

    test('chilled packages default to the fridge', () {
      final entry = entryFromAnalysis(
        analysis(category: 'Dairy', packageSize: '500 g'),
        fromBarcode: true,
      );
      expect(entry.location, StorageLocation.fridge);
    });

    test('Scan Food keeps the Fridge default', () {
      final entry = entryFromAnalysis(analysis());
      expect(entry.location, StorageLocation.fridge);
    });
  });

  test('barcode errors use barcode wording', () {
    const e = AiException(AiErrorCode.invalidInput);
    expect(aiErrorMessage(e, barcode: true), contains('barcode'));
    expect(aiErrorMessage(e), contains('photo'));
  });
}
