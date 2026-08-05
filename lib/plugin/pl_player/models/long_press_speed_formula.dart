enum LongPressSpeedFormula {
  multiply('乘法', '当前倍速 × 增益'),
  add('加法', '当前倍速 + 增益'),
  custom('自定义', '自定义公式'),
  ;

  final String label;
  final String description;
  const LongPressSpeedFormula(this.label, this.description);

  static LongPressSpeedFormula fromIndex(Object? value) {
    final index = value is int ? value : multiply.index;
    if (index < 0 || index >= values.length) {
      return multiply;
    }
    return values[index];
  }

  double resolve({
    required double playbackSpeed,
    required double gain,
    required String customFormula,
  }) {
    final fallback = playbackSpeed * gain;
    final result = switch (this) {
      multiply => fallback,
      add => playbackSpeed + gain,
      custom =>
        _FormulaParser(customFormula, playbackSpeed, gain).tryParse() ??
            fallback,
    };

    if (_isValidSpeed(result)) {
      return result;
    }
    if (_isValidSpeed(fallback)) {
      return fallback;
    }
    return playbackSpeed;
  }

  static bool isValidCustomFormula(String formula) {
    return _isValidSpeed(_FormulaParser(formula, 1.0, 2.0).tryParse());
  }

  static bool _isValidSpeed(double? value) {
    return value != null && value.isFinite && value > 0;
  }
}

abstract final class LongPressSpeedFormulaDefaults {
  static const double gain = 2.0;
  static const String customFormula = 'x * g';
}

class _FormulaParser {
  _FormulaParser(this._source, this._speed, this._gain);

  final String _source;
  final double _speed;
  final double _gain;
  int _pos = 0;

  double? tryParse() {
    try {
      final result = _parseExpression();
      _skipSpaces();
      if (!_isAtEnd) {
        throw const FormatException('Unexpected token');
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  bool get _isAtEnd => _pos >= _source.length;

  void _skipSpaces() {
    while (!_isAtEnd) {
      final code = _source.codeUnitAt(_pos);
      if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D) {
        _pos++;
      } else {
        return;
      }
    }
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      if (_matchAny(const ['+', '＋'])) {
        value += _parseTerm();
      } else if (_matchAny(const ['-', '－'])) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      if (_matchAny(const ['*', '×'])) {
        value *= _parseFactor();
      } else if (_matchAny(const ['/', '÷'])) {
        value /= _parseFactor();
      } else {
        return value;
      }
    }
  }

  double _parseFactor() {
    _skipSpaces();
    if (_matchAny(const ['+', '＋'])) {
      return _parseFactor();
    }
    if (_matchAny(const ['-', '－'])) {
      return -_parseFactor();
    }
    if (_matchAny(const ['(', '（'])) {
      final value = _parseExpression();
      if (!_matchAny(const [')', '）'])) {
        throw const FormatException('Missing closing parenthesis');
      }
      return value;
    }
    if (_isNumberStart()) {
      return _parseNumber();
    }
    if (_isIdentifierStart()) {
      return _parseIdentifier();
    }
    throw const FormatException('Unexpected token');
  }

  bool _matchAny(List<String> chars) {
    _skipSpaces();
    for (final char in chars) {
      if (_source.startsWith(char, _pos)) {
        _pos += char.length;
        return true;
      }
    }
    return false;
  }

  bool _isNumberStart() {
    if (_isAtEnd) {
      return false;
    }
    final code = _source.codeUnitAt(_pos);
    return _isDigit(code) || code == 0x2E;
  }

  double _parseNumber() {
    final start = _pos;
    var hasDigit = false;
    while (!_isAtEnd && _isDigit(_source.codeUnitAt(_pos))) {
      hasDigit = true;
      _pos++;
    }
    if (!_isAtEnd && _source.codeUnitAt(_pos) == 0x2E) {
      _pos++;
      while (!_isAtEnd && _isDigit(_source.codeUnitAt(_pos))) {
        hasDigit = true;
        _pos++;
      }
    }
    if (!hasDigit) {
      throw const FormatException('Invalid number');
    }
    if (!_isAtEnd) {
      final code = _source.codeUnitAt(_pos);
      if (code == 0x45 || code == 0x65) {
        _parseExponent();
      }
    }
    return double.parse(_source.substring(start, _pos));
  }

  void _parseExponent() {
    _pos++;
    if (!_isAtEnd) {
      final code = _source.codeUnitAt(_pos);
      if (code == 0x2B || code == 0x2D) {
        _pos++;
      }
    }
    var hasDigit = false;
    while (!_isAtEnd && _isDigit(_source.codeUnitAt(_pos))) {
      hasDigit = true;
      _pos++;
    }
    if (!hasDigit) {
      throw const FormatException('Invalid exponent');
    }
  }

  bool _isIdentifierStart() {
    if (_isAtEnd) {
      return false;
    }
    final code = _source.codeUnitAt(_pos);
    return _isAsciiLetter(code) || code == 0x5F;
  }

  double _parseIdentifier() {
    final start = _pos;
    while (!_isAtEnd) {
      final code = _source.codeUnitAt(_pos);
      if (_isAsciiLetter(code) || _isDigit(code) || code == 0x5F) {
        _pos++;
      } else {
        break;
      }
    }
    return switch (_source.substring(start, _pos).toLowerCase()) {
      'x' || 's' || 'speed' || 'base' || 'current' => _speed,
      'g' || 'gain' || 'boost' || 'factor' => _gain,
      _ => throw const FormatException('Unknown variable'),
    };
  }

  bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  bool _isAsciiLetter(int code) {
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A);
  }
}
