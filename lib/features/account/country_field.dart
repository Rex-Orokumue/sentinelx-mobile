import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

const _unsupportedPhoneRegions = ['HM', 'GS'];

const _canonicalNamesByCode = <String, String>{
  'AG': 'Antigua & Barbuda',
  'BA': 'Bosnia & Herzegovina',
  'CD': 'Congo - Kinshasa',
  'CG': 'Congo - Brazzaville',
  'CZ': 'Czechia',
  'TL': 'Timor-Leste',
  'FK': 'Falkland Islands',
  'GN': 'Guinea',
  'HK': 'Hong Kong SAR China',
  'MO': 'Macao SAR China',
  'BL': 'St. Barthélemy',
  'SH': 'St. Helena',
  'KN': 'St. Kitts & Nevis',
  'MF': 'St. Martin',
  'PM': 'St. Pierre & Miquelon',
  'VC': 'St. Vincent & Grenadines',
  'ST': 'São Tomé & Príncipe',
  'SJ': 'Svalbard & Jan Mayen',
  'TR': 'Türkiye',
  'TC': 'Turks & Caicos Islands',
  'WF': 'Wallis & Futuna',
};

String canonicalCountryName(Country country) =>
    _canonicalNamesByCode[country.countryCode] ?? country.name;

class CountryField extends StatelessWidget {
  const CountryField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  final String label;
  final String placeholder;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('country-field'),
    onTap: enabled
        ? () => showCountryPicker(
            context: context,
            showPhoneCode: false,
            useSafeArea: true,
            exclude: _unsupportedPhoneRegions,
            onSelect: (country) => onChanged(canonicalCountryName(country)),
          )
        : null,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        enabled: enabled,
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(value?.isNotEmpty == true ? value! : placeholder),
    ),
  );
}
