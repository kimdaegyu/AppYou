/// 판정 비교에 쓰는 유리수. 십진 문자열에서만 만들고 교차곱으로 비교한다.
class QuizRatio implements Comparable<QuizRatio> {
  const QuizRatio._(this.numerator, this.denominator);

  final BigInt numerator;
  final BigInt denominator;

  factory QuizRatio.integer(int value) {
    return QuizRatio._(BigInt.from(value), BigInt.one);
  }

  factory QuizRatio.decimal(String text) {
    final negative = text.startsWith('-');
    final body = negative ? text.substring(1) : text;
    if (body.contains('/')) {
      final parts = body.split('/');
      if (parts.length != 2) {
        throw FormatException(text);
      }
      var numerator = BigInt.parse(parts[0]);
      final denominator = BigInt.parse(parts[1]);
      if (negative) {
        numerator = -numerator;
      }
      return QuizRatio._(numerator, denominator).reduced;
    }
    if (body.isEmpty || body.contains('-') || '.'.allMatches(body).length > 1) {
      throw FormatException(text);
    }
    final parts = body.split('.');
    if (parts.any((part) => part.isNotEmpty && int.tryParse(part) == null)) {
      throw FormatException(text);
    }
    final whole = parts[0].isEmpty ? '0' : parts[0];
    final fraction = parts.length == 1 ? '' : parts[1];
    final digits = '$whole$fraction';
    var numerator = BigInt.parse(digits.isEmpty ? '0' : digits);
    if (negative) {
      numerator = -numerator;
    }
    return QuizRatio._(numerator, BigInt.from(10).pow(fraction.length)).reduced;
  }

  QuizRatio get reduced {
    final divisor = numerator.gcd(denominator);
    var nextNumerator = numerator ~/ divisor;
    var nextDenominator = denominator ~/ divisor;
    if (nextDenominator.isNegative) {
      nextNumerator = -nextNumerator;
      nextDenominator = -nextDenominator;
    }
    return QuizRatio._(nextNumerator, nextDenominator);
  }

  QuizRatio operator +(QuizRatio other) {
    return QuizRatio._(
      numerator * other.denominator + other.numerator * denominator,
      denominator * other.denominator,
    ).reduced;
  }

  QuizRatio operator -(QuizRatio other) {
    return QuizRatio._(
      numerator * other.denominator - other.numerator * denominator,
      denominator * other.denominator,
    ).reduced;
  }

  QuizRatio operator *(QuizRatio other) {
    return QuizRatio._(numerator * other.numerator, denominator * other.denominator).reduced;
  }

  QuizRatio operator /(QuizRatio other) {
    return QuizRatio._(numerator * other.denominator, denominator * other.numerator).reduced;
  }

  bool operator <=(QuizRatio other) => compareTo(other) <= 0;

  bool operator >=(QuizRatio other) => compareTo(other) >= 0;

  @override
  int compareTo(QuizRatio other) {
    return (numerator * other.denominator).compareTo(other.numerator * denominator);
  }

  @override
  bool operator ==(Object other) => other is QuizRatio && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(reduced.numerator, reduced.denominator);

  /// 소수 첫째 자리 half-up. 음수가 아닌 점수에 맞춘다.
  String get tenths {
    final scaled = numerator * BigInt.from(10);
    final remainder = scaled.remainder(denominator);
    var quote = scaled ~/ denominator;
    final positiveRemainder = remainder.isNegative ? -remainder : remainder;
    final span = denominator.isNegative ? -denominator : denominator;
    if (positiveRemainder * BigInt.two >= span) {
      quote += quote.isNegative ? -BigInt.one : BigInt.one;
    }
    final negative = quote.isNegative;
    final absolute = quote.abs();
    final whole = absolute ~/ BigInt.from(10);
    final fraction = absolute.remainder(BigInt.from(10));
    final text = '$whole.$fraction';
    return negative ? '-$text' : text;
  }
}
