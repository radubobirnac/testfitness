import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';

void main() {
  const formatter = DecimalWeightInputFormatter();

  String apply(String oldText, String newText) {
    return formatter
        .formatEditUpdate(
          TextEditingValue(
            text: oldText,
            selection: TextSelection.collapsed(offset: oldText.length),
          ),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        )
        .text;
  }

  group('DecimalWeightInputFormatter', () {
    test('accepts integers and decimals', () {
      expect(apply('', '60'), '60');
      expect(apply('62', '62.'), '62.');
      expect(apply('62.', '62.5'), '62.5');
      expect(apply('62.5', '62.25'), '62.25');
    });

    test('normalises a comma decimal separator to a dot', () {
      expect(apply('62', '62,'), '62.');
      expect(apply('62', '62,5'), '62.5');
    });

    test('rejects a second separator, letters and too many decimals', () {
      expect(apply('62.5', '62.5.'), '62.5');
      expect(apply('62.5', '62.5,'), '62.5');
      expect(apply('62', '62a'), '62');
      expect(apply('62.25', '62.255'), '62.25');
      expect(apply('62', '-62'), '62');
    });

    test('allows clearing the field', () {
      expect(apply('62', ''), '');
    });
  });
}
