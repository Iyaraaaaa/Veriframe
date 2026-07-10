import 'package:flutter/material.dart';

class LanguageSwitcher extends StatelessWidget {
  final Function(Locale) onLocaleChange;
  final Locale locale;
  const LanguageSwitcher({super.key, required this.onLocaleChange, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _langBtn('සිංහල', 'si'),
        _langBtn('English', 'en'),
        _langBtn('தமிழ்', 'ta'),
      ],
    );
  }

  Widget _langBtn(String label, String code) {
    return TextButton(
      onPressed: () => onLocaleChange(Locale(code)),
      child: Text(
        label,
        style: TextStyle(
          color: locale.languageCode == code ? Colors.white : Colors.grey,
        ),
      ),
    );
  }
}


