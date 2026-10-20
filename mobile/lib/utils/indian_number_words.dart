class IndianNumberWords {
  static const _units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(num number) {
    int n = number.toInt();
    if (n == 0) return 'Zero Rupees Only';
    if (n < 0) return 'Minus ${convert(-n)}';

    String words = '';
    if (n >= 10000000) {
      words += '${_convertPart(n ~/ 10000000)} Crore ';
      n %= 10000000;
    }
    if (n >= 100000) {
      words += '${_convertPart(n ~/ 100000)} Lakh ';
      n %= 100000;
    }
    if (n >= 1000) {
      words += '${_convertPart(n ~/ 1000)} Thousand ';
      n %= 1000;
    }
    if (n >= 100) {
      words += '${_convertPart(n ~/ 100)} Hundred ';
      n %= 100;
    }
    if (n > 0) {
      words += _convertPart(n);
    }
    return '${words.trim()} Rupees Only';
  }

  static String _convertPart(int n) {
    if (n < 20) return _units[n];
    final ten = _tens[n ~/ 10];
    final unit = _units[n % 10];
    return unit.isEmpty ? ten : '$ten $unit';
  }
}
