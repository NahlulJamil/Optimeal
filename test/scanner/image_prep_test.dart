import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/features/scanner/data/image_prep.dart';

void main() {
  group('shorterSideFor keeps the longest side within the limit', () {
    int longestAfter(int w, int h, int maxSide) {
      final shorter = w < h ? w : h;
      final longer = w < h ? h : w;
      final min = shorterSideFor(width: w, height: h, maxSide: maxSide);
      return (longer * min / shorter).round();
    }

    test('720p camera photo, both orientations', () {
      expect(longestAfter(1280, 720, 1024), lessThanOrEqualTo(1024));
      expect(longestAfter(720, 1280, 1024), lessThanOrEqualTo(1024));
      expect(longestAfter(1280, 720, 1024), greaterThan(1000));
    });

    test('large gallery photo and 512 px thumbnail', () {
      expect(longestAfter(4000, 3000, 1024), lessThanOrEqualTo(1024));
      expect(longestAfter(3000, 4000, 512), lessThanOrEqualTo(512));
    });

    test('small images are not enlarged', () {
      expect(shorterSideFor(width: 800, height: 600, maxSide: 1024), 600);
    });
  });
}
