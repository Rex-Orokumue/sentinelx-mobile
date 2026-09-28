enum RegistrationFieldInputType { text, number, url }

RegistrationFieldInputType _parseInputType(String value) => switch (value) {
  'text' => RegistrationFieldInputType.text,
  'number' => RegistrationFieldInputType.number,
  'url' => RegistrationFieldInputType.url,
  _ => throw FormatException('Unknown registration field input type: $value'),
};

class RegistrationField {
  const RegistrationField({
    required this.fieldKey,
    required this.label,
    required this.placeholder,
    required this.inputType,
    required this.required,
    required this.validationPattern,
    required this.validationMessage,
  });

  factory RegistrationField.fromJson(Map<String, dynamic> json) =>
      RegistrationField(
        fieldKey: json['fieldKey'] as String,
        label: json['label'] as String,
        placeholder: json['placeholder'] as String?,
        inputType: _parseInputType(json['inputType'] as String),
        required: json['required'] as bool,
        validationPattern: json['validationPattern'] as String?,
        validationMessage: json['validationMessage'] as String?,
      );

  final String fieldKey;
  final String label;
  final String? placeholder;
  final RegistrationFieldInputType inputType;
  final bool required;
  final String? validationPattern;
  final String? validationMessage;

  String? validate(String value) {
    final trimmed = value.trim();
    if (required && trimmed.isEmpty) return '$label is required';
    if (trimmed.length > 120) return '$label is too long';
    if (trimmed.isEmpty || validationPattern == null) return null;
    try {
      if (!RegExp(validationPattern!).hasMatch(trimmed)) {
        return validationMessage ?? '$label is invalid';
      }
    } on FormatException {
      // Raw SQL seeding can bypass catalogue validation. Match the server's defensive posture.
    }
    return null;
  }
}
