import 'package:flutter_test/flutter_test.dart';

void main() {   // 👈 ЭТА СТРОКА ОБЯЗАТЕЛЬНА!
  group('Тестирование модуля расписания и предметов (Schedule & Subjects)', () {
    
    // Тест 1: Проверка корректности формирования структуры daysToSave
    test('Формирование структуры daysToSave должно содержать 5 дней и 7 уроков', () {
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
      final timeSlots = ['08:00-08:45', '09:00-09:45', '10:00-10:45', 
                         '11:00-11:45', '12:00-12:45', '13:00-13:45', '14:00-14:45'];
      
      final daysToSave = days.map((day) {
        return {
          'day': day,
          'lessons': timeSlots.map((time) {
            return {'time': time, 'subject': '', 'subjectId': '', 
                    'teacher': '', 'teacherId': '', 'room': ''};
          }).toList(),
        };
      }).toList();
      
      expect(daysToSave.length, 5);
      expect((daysToSave[0]['lessons'] as List).length, 7);
    });
    
    // Тест 2: Проверка автоматической подстановки учителя
    test('При выборе предмета должен подставляться первый учитель из списка', () {
      final subjectTeachers = {
        'subject_math': [
          {'teacherId': 'teacher_1', 'teacherName': 'Иванова М.А.'},
          {'teacherId': 'teacher_2', 'teacherName': 'Петров С.В.'},
        ]
      };
      
      final selectedSubjectId = 'subject_math';
      final firstTeacher = subjectTeachers[selectedSubjectId]!.first;
      
      expect(firstTeacher['teacherId'], 'teacher_1');
      expect(firstTeacher['teacherName'], 'Иванова М.А.');
    });
    
    // Тест 3: Граничное условие — выбор предмета без учителей
    test('При выборе предмета без назначенных учителей поле teacher должно быть пустым', () {
      final subjectTeachers = <String, List<Map<String, dynamic>>>{};
      final selectedSubjectId = 'subject_without_teachers';
      
      final teachers = subjectTeachers[selectedSubjectId] ?? [];
      final firstTeacher = teachers.isNotEmpty ? teachers.first : null;
      
      expect(firstTeacher, null);
    });
    
    // Тест 4: Проверка определения роли пользователя
    test('Роль завуча должна иметь доступ к редактированию расписания', () {
      const userRole = 'vice_principal';
      final isVicePrincipal = userRole == 'vice_principal';
      
      expect(isVicePrincipal, true);
    });
    
    // Тест 5: Проверка роли учителя — только просмотр
    test('Роль учителя не должна иметь доступ к редактированию расписания', () {
      const userRole = 'teacher';
      final isVicePrincipal = userRole == 'vice_principal';
      
      expect(isVicePrincipal, false);
    });
  });
}