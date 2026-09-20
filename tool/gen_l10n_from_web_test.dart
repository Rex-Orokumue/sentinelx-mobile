import 'package:test/test.dart';
import '../tool/gen_l10n_from_web.dart';

void main() {
  group('toArbKey', () {
    test('camelCases a namespace-qualified path', () {
      expect(toArbKey(['auth', 'login', 'title']), 'authLoginTitle');
    });
    test('handles a two-segment (flat-namespace) path', () {
      expect(toArbKey(['terms', 's1Heading']), 'termsS1Heading');
    });
  });

  group('flattenNamespace', () {
    test('flattens a nested namespace with dotted prefixing', () {
      final result = flattenNamespace({
        'login': {'title': 'Welcome back', 'submit': 'Log in'},
        'errors': {'invalid_email': 'Enter a valid email address.'},
      }, 'auth');
      expect(result, {
        'authLoginTitle': 'Welcome back',
        'authLoginSubmit': 'Log in',
        'authErrorsInvalidEmail': 'Enter a valid email address.',
      });
    });

    test('flattens a flat namespace with one level of prefixing', () {
      final result = flattenNamespace({'title': 'Terms of Service', 's1Heading': '1. Who We Are'}, 'terms');
      expect(result, {'termsTitle': 'Terms of Service', 'termsS1Heading': '1. Who We Are'});
    });

    test('substitutes ICU placeholders from {curly} to {curly} unchanged (ARB already uses that syntax)', () {
      final result = flattenNamespace({'checkEmailBody': 'We sent a link to {email}.'}, 'signup');
      expect(result['signupCheckEmailBody'], 'We sent a link to {email}.');
    });
  });
}
