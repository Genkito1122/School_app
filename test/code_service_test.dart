import 'package:flutter_test/flutter_test.dart';

class CodeService {
  String generateAdminCode() {
    return 'ADM${DateTime.now().millisecondsSinceEpoch}${_randomSuffix()}';
  }
  
  String generateTeacherCode(String schoolId) {
    return 'TCH${DateTime.now().millisecondsSinceEpoch}${_randomSuffix()}';
  }
  
  String generateStudentCode(String classId) {
    return 'STU${DateTime.now().millisecondsSinceEpoch}${_randomSuffix()}';
  }
  
  bool verifyCode(String code) {
    return code.startsWith('ADM') || code.startsWith('TCH') || code.startsWith('STU');
  }
  
  String _randomSuffix() {
    return '${DateTime.now().microsecondsSinceEpoch}'.substring(8);
  }
}

void main() {
  group('Автоматизированное тестирование сервиса кодов', () {
    late CodeService codeService;

    setUp(() {
      codeService = CodeService();
    });

    test('Успешная генерация кода администратора', () {
      final code = codeService.generateAdminCode();
      expect(code, startsWith('ADM'));
      expect(code.length, greaterThan(10));
    });

    test('Успешная генерация кода учителя', () {
      const schoolId = 'school_123';
      final code = codeService.generateTeacherCode(schoolId);
      expect(code, startsWith('TCH'));
      expect(code.length, greaterThan(10));
    });

    test('Успешная генерация кода ученика', () {
      const classId = 'class_456';
      final code = codeService.generateStudentCode(classId);
      expect(code, startsWith('STU'));
      expect(code.length, greaterThan(10));
    });

    test('Проверка валидности кодов', () {
      final validCodes = [
        'ADM123456789',
        'TCH987654321', 
        'STU555555555'
      ];
      
      final invalidCodes = [
        'INVALID123',
        'ABC987654321',
        '123456789012'
      ];

      for (final code in validCodes) {
        final isValid = codeService.verifyCode(code);
        expect(isValid, isTrue, reason: 'Код $code должен быть валидным');
      }
      
      for (final code in invalidCodes) {
        final isValid = codeService.verifyCode(code);
        expect(isValid, isFalse, reason: 'Код $code должен быть невалидным');
      }
    });

    test('Проверка формата кодов', () {
      final adminCode = codeService.generateAdminCode();
      final teacherCode = codeService.generateTeacherCode('test');
      final studentCode = codeService.generateStudentCode('test');
      expect(adminCode, startsWith('ADM'));
      expect(teacherCode, startsWith('TCH'));
      expect(studentCode, startsWith('STU'));
      expect(adminCode.length, greaterThan(8));
      expect(teacherCode.length, greaterThan(8));
      expect(studentCode.length, greaterThan(8));
    });
  });
}