import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/core/services/auth_service.dart';

void main() {
  group('AuthService.normalizeSchoolEmail', () {
    test('normalizes surrounding whitespace and case', () {
      expect(
        AuthService.normalizeSchoolEmail('  Student@VISION.HOSEO.EDU  '),
        'student@vision.hoseo.edu',
      );
    });

    test('accepts only exact configured test email addresses', () {
      const allowed = {'tester@example.com'};

      expect(
        AuthService.normalizeSchoolEmail(
          ' Tester@Example.com ',
          allowedTestEmails: allowed,
        ),
        'tester@example.com',
      );
      expect(
        () => AuthService.normalizeSchoolEmail(
          'tester+other@example.com',
          allowedTestEmails: allowed,
        ),
        throwsA(isA<InvalidSchoolEmailException>()),
      );
    });

    for (final invalidEmail in <String>[
      '',
      '@vision.hoseo.edu',
      'student@gmail.com',
      'student@vision.hoseo.edu.evil.com',
      'student@sub.vision.hoseo.edu',
      'student@@vision.hoseo.edu',
      'stu dent@vision.hoseo.edu',
    ]) {
      test('rejects invalid address: $invalidEmail', () {
        expect(
          () => AuthService.normalizeSchoolEmail(invalidEmail),
          throwsA(isA<InvalidSchoolEmailException>()),
        );
      });
    }
  });

  test('심사용 계정은 테스트 이메일로도 허용된다', () {
    final service = AuthService(
      null,
      allowedTestEmails: const {'tester@example.com'},
      reviewEmails: const {'review@example.com'},
    );

    expect(service.reviewEmails, {'review@example.com'});
    expect(
      AuthService.normalizeSchoolEmail(
        'Review@Example.com',
        allowedTestEmails: service.allowedTestEmails,
      ),
      'review@example.com',
    );
    expect(service.allowedTestEmails, contains('tester@example.com'));
  });
}
