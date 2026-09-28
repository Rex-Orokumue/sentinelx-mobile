import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/registration_fields_models.dart';

void main() {
  const requiredField = RegistrationField(
    fieldKey: 'player_id',
    label: 'Player ID',
    placeholder: '12345',
    inputType: RegistrationFieldInputType.number,
    required: true,
    validationPattern: r'^\d+$',
    validationMessage: 'Use digits only',
  );

  test('parses every registration field property', () {
    final field = RegistrationField.fromJson({
      'fieldKey': 'profile',
      'label': 'Profile URL',
      'placeholder': null,
      'inputType': 'url',
      'required': false,
      'validationPattern': r'^https://',
      'validationMessage': null,
    });
    expect(field.fieldKey, 'profile');
    expect(field.inputType, RegistrationFieldInputType.url);
    expect(field.required, isFalse);
  });

  test('validates required and pattern rules after trimming', () {
    expect(requiredField.validate('  '), 'Player ID is required');
    expect(requiredField.validate(' abc '), 'Use digits only');
    expect(requiredField.validate(' 12345 '), isNull);
  });

  test(
    'uses a generic pattern message and ignores invalid catalogue regex',
    () {
      const generic = RegistrationField(
        fieldKey: 'tag',
        label: 'Tag',
        placeholder: null,
        inputType: RegistrationFieldInputType.text,
        required: false,
        validationPattern: r'^ok$',
        validationMessage: null,
      );
      const malformed = RegistrationField(
        fieldKey: 'tag',
        label: 'Tag',
        placeholder: null,
        inputType: RegistrationFieldInputType.text,
        required: false,
        validationPattern: '[',
        validationMessage: 'bad',
      );
      expect(generic.validate('no'), 'Tag is invalid');
      expect(malformed.validate('anything'), isNull);
    },
  );
}
