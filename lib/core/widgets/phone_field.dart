import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class Country {
  const Country({required this.flag, required this.code, required this.nationalLength});
  final String flag;
  final String code;
  final int nationalLength;
}

const kPhoneCountries = <Country>[
  Country(flag: '🇿🇲', code: '+260', nationalLength: 9), // Zambia (default)
  Country(flag: '🇰🇪', code: '+254', nationalLength: 9),
  Country(flag: '🇹🇿', code: '+255', nationalLength: 9),
  Country(flag: '🇺🇬', code: '+256', nationalLength: 9),
  Country(flag: '🇨🇩', code: '+243', nationalLength: 9),
  Country(flag: '🇿🇼', code: '+263', nationalLength: 9),
  Country(flag: '🇲🇼', code: '+265', nationalLength: 9),
  Country(flag: '🇲🇿', code: '+258', nationalLength: 9),
  Country(flag: '🇧🇼', code: '+267', nationalLength: 8),
  Country(flag: '🇷🇼', code: '+250', nationalLength: 9),
  Country(flag: '🇳🇬', code: '+234', nationalLength: 10),
  Country(flag: '🇬🇭', code: '+233', nationalLength: 9),
  Country(flag: '🇿🇦', code: '+27', nationalLength: 9),
];

/// Smart mobile number field: country code picker (defaults to Zambia),
/// auto-detects pasted international numbers, keeps the national part formatted.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    this.initialValue,
    this.onChanged,
    this.labelText = 'Mobile number',
    this.helperText,
  });

  /// Optional existing number (national or E.164).
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final String labelText;
  final String? helperText;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late final TextEditingController _controller;
  late Country _country;

  @override
  void initState() {
    super.initState();
    _country = kPhoneCountries.first;
    _controller = TextEditingController(text: _nationalPartOf(widget.initialValue) ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get e164 {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('0') ? digits.substring(1) : digits;
    return national.isEmpty ? '' : '${_country.code}$national';
  }

  String? _nationalPartOf(String? value) {
    if (value == null || value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final sorted = [...kPhoneCountries]..sort((a, b) => b.code.length - a.code.length);
    for (final c in sorted) {
      final cc = c.code.replaceAll('+', '');
      if (digits.startsWith(cc)) {
        _country = c;
        return digits.substring(cc.length);
      }
    }
    return digits;
  }

  void _handleChanged(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      widget.onChanged?.call('');
      return;
    }

    final sorted = [...kPhoneCountries]..sort((a, b) => b.code.length - a.code.length);

    // Pasted full international number ("00260968..." or "+260968...").
    final isInternational = digits.startsWith('00') || digits.startsWith('+') ||
        (digits.length > 11 && digits.startsWith('260'));
    if (isInternational) {
      var probe = digits.startsWith('00') ? '+${digits.substring(2)}'
          : digits.startsWith('+') ? digits
          : '+$digits';
      for (final c in sorted) {
        if (probe.startsWith(c.code)) {
          setState(() => _country = c);
          _controller.text = probe.substring(c.code.length);
          widget.onChanged?.call(e164);
          return;
        }
      }
    }

    // Plain national digits.
    final national = digits.startsWith('0') ? digits.substring(1) : digits;
    final limited =
        national.length > _country.nationalLength ? national.substring(0, _country.nationalLength) : national;
    final formatted = _group('0$limited');
    if (formatted != _controller.text) {
      _controller.text = formatted;
      _controller.selection = TextSelection.collapsed(offset: formatted.length);
    }
    widget.onChanged?.call(e164);
  }

  String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
      ],
      maxLength: _country.nationalLength + 1,
      onChanged: _handleChanged,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: '0977 123 456',
        helperText: widget.helperText,
        counterText: '',
        prefixIcon: PopupMenuButton<Country>(
          tooltip: 'Country code',
          onSelected: (c) {
            setState(() => _country = c);
            widget.onChanged?.call(e164);
          },
          itemBuilder: (context) => [
            for (final c in kPhoneCountries)
              PopupMenuItem(
                value: c,
                child: Text('${c.flag}  ${c.code}', style: const TextStyle(fontSize: 15)),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_country.flag} ${_country.code}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
