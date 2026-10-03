import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

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
            onSelect: (country) => onChanged(country.name),
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
