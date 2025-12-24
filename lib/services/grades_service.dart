import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GradesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== ПОЛУЧЕНИЕ ДАННЫХ ====================

  // Получить учеников класса
  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    final snapshot = await _firestore
        .collection('students')
        .where('classId', isEqualTo: classId)
        .orderBy('fullName')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'studentId': doc.id,
        'fullName': data['fullName'] ?? 'Неизвестно',
        'email': data['email'] ?? '',
        'className': data['className'] ?? '',
      };
    }).toList();
  }

  // Получить предметы учителя
  Future<List<Map<String, dynamic>>> getTeacherSubjects(String teacherId) async {
  print('🔄 Загрузка предметов для учителя: $teacherId');
  
  try {
    // 1. Получаем назначения учителя
    final assignmentsSnapshot = await _firestore
        .collection('teacher_subject_assignments')
        .where('teacherId', isEqualTo: teacherId)
        .where('isActive', isEqualTo: true)
        .get();

    if (assignmentsSnapshot.docs.isEmpty) {
      print('⚠️ У учителя $teacherId нет активных назначений');
      return [];
    }

    final List<Map<String, dynamic>> subjects = [];

    for (final assignmentDoc in assignmentsSnapshot.docs) {
      final assignment = assignmentDoc.data();
      final subjectId = assignment['subjectId'] as String?;
      
      if (subjectId == null || subjectId.isEmpty) {
        print('⚠️ Пустой subjectId в назначении ${assignmentDoc.id}');
        continue;
      }

      // 2. Получаем информацию о предмете
      final subjectDoc = await _firestore
          .collection('school_subjects')
          .doc(subjectId)
          .get();

      if (!subjectDoc.exists) {
        print('⚠️ Предмет $subjectId не найден');
        continue;
      }

      final subjectData = subjectDoc.data()!;
      final subjectName = subjectData['name'] as String? ?? 'Неизвестно';

      // 3. Получаем классы учителя
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (!teacherDoc.exists) {
        print('⚠️ Учитель $teacherId не найден');
        continue;
      }

      final teacherData = teacherDoc.data()!;
      final classIds = List<String>.from(teacherData['classIds'] ?? []);

      if (classIds.isEmpty) {
        print('⚠️ У учителя $teacherId нет классов');
        continue;
      }

      // 4. Для каждого класса создаем запись
      for (final classId in classIds) {
        final classDoc = await _firestore
            .collection('classes')
            .doc(classId)
            .get();

        if (classDoc.exists) {
          final classData = classDoc.data()!;
          final className = classData['name'] as String? ?? 'Без названия';
          
          subjects.add({
            'subjectId': subjectId,
            'name': subjectName,
            'classId': classId,
            'className': className,
            'schoolId': subjectData['schoolId'],
            'assignmentId': assignmentDoc.id,
          });
          
          print('✅ Добавлен предмет: $subjectName для класса $className');
        }
      }
    }

    print('🎉 Всего загружено предметов: ${subjects.length}');
    return subjects;

  } catch (e) {
    print('❌ КРИТИЧЕСКАЯ ошибка в getTeacherSubjects: $e');
    print('📋 Stack trace: ${e.toString()}');
    return [];
  }
}


  Future<void> addGrade({
    required String studentId,
    required String subjectId,
    required String subjectName,
    required String studentName,
    required String classId,
    required int grade,
    String comment = '',
    String type = 'lesson',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    final teacherDoc = await _firestore.collection('teachers').doc(user.uid).get();
    final teacherName = teacherDoc.data()?['fullName'] ?? 'Учитель';

    final docId = '${studentId}_$subjectId';

    // Получаем текущие данные
    final doc = await _firestore.collection('grades_system').doc(docId).get();
    final existingGrades = List<Map<String, dynamic>>.from(doc.data()?['grades'] ?? []);

    final newGrade = {
      'value': grade,
      'comment': comment,
      'type': type,
      'addedBy': user.uid,
    };

    existingGrades.add(newGrade);

    final average = _calculateAverage(existingGrades);

    await _firestore.collection('grades_system').doc(docId).set({
      'studentId': studentId,
      'studentName': studentName,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'teacherId': user.uid,
      'teacherName': teacherName,
      'classId': classId,
      'grades': existingGrades,
      'average': average,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getStudentGrades(String studentId, String subjectId) async {
    final docId = '${studentId}_$subjectId';
    final doc = await _firestore.collection('grades_system').doc(docId).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'studentId': studentId,
      'studentName': data['studentName'],
      'subjectId': subjectId,
      'subjectName': data['subjectName'],
      'grades': List<Map<String, dynamic>>.from(data['grades'] ?? []),
      'average': data['average'] ?? 0,
      'lastUpdated': data['lastUpdated'],
    };
  }

  // Получить все оценки класса по предмету
  Future<Map<String, dynamic>> getClassGrades(String classId, String subjectId) async {
    final snapshot = await _firestore
        .collection('grades_system')
        .where('classId', isEqualTo: classId)
        .where('subjectId', isEqualTo: subjectId)
        .get();

    final students = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      students.add({
        'studentId': data['studentId'],
        'studentName': data['studentName'],
        'grades': List<Map<String, dynamic>>.from(data['grades'] ?? []),
        'average': data['average'] ?? 0,
        'lastUpdated': data['lastUpdated'],
      });
    }

    // Сортируем по алфавиту
    students.sort((a, b) => (a['studentName'] as String).compareTo(b['studentName'] as String));

    return {
      'students': students,
      'totalStudents': students.length,
    };
  }

  // Получить все оценки ученика (для ученика/родителя)
  Future<List<Map<String, dynamic>>> getStudentAllGrades(String studentId) async {
    final snapshot = await _firestore
        .collection('grades_system')
        .where('studentId', isEqualTo: studentId)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      result.add({
        'subjectId': data['subjectId'],
        'subjectName': data['subjectName'],
        'teacherName': data['teacherName'],
        'grades': List<Map<String, dynamic>>.from(data['grades'] ?? []),
        'average': data['average'] ?? 0,
        'lastUpdated': data['lastUpdated'],
      });
    }

    // Сортируем по предметам
    result.sort((a, b) => (a['subjectName'] as String).compareTo(b['subjectName'] as String));

    return result;
  }

  // Удалить оценку
  Future<void> deleteGrade({
    required String studentId,
    required String subjectId,
    required int gradeIndex,
  }) async {
    final docId = '${studentId}_$subjectId';
    final doc = await _firestore.collection('grades_system').doc(docId).get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final grades = List<Map<String, dynamic>>.from(data['grades'] ?? []);

    if (gradeIndex < 0 || gradeIndex >= grades.length) return;

    // Удаляем оценку
    grades.removeAt(gradeIndex);

    // Вычисляем новый средний
    final average = _calculateAverage(grades);

    // Обновляем
    await _firestore.collection('grades_system').doc(docId).update({
      'grades': grades,
      'average': average,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  double _calculateAverage(List<Map<String, dynamic>> grades) {
    if (grades.isEmpty) return 0;

    double total = 0;
    for (final grade in grades) {
      total += (grade['value'] as int).toDouble();
    }

    return double.parse((total / grades.length).toStringAsFixed(2));
  }

  // Получить статистику
  Future<Map<String, dynamic>> getStatistics(String classId, String subjectId) async {
    final classGrades = await getClassGrades(classId, subjectId);
    final students = classGrades['students'] as List<Map<String, dynamic>>;

    if (students.isEmpty) {
      return {
        'classAverage': 0,
        'totalGrades': 0,
        'bestStudent': null,
        'worstStudent': null,
      };
    }

    double classTotal = 0;
    int totalGrades = 0;
    Map<String, dynamic>? bestStudent;
    Map<String, dynamic>? worstStudent;
    double bestAverage = 0;
    double worstAverage = 5;

    for (final student in students) {
      final average = (student['average'] as double?) ?? 0;
      final grades = List<Map<String, dynamic>>.from(student['grades'] ?? []);
      
      classTotal += average;
      totalGrades += grades.length;

      if (average > bestAverage) {
        bestAverage = average;
        bestStudent = student;
      }

      if (average < worstAverage) {
        worstAverage = average;
        worstStudent = student;
      }
    }

    return {
      'classAverage': double.parse((classTotal / students.length).toStringAsFixed(2)),
      'totalGrades': totalGrades,
      'bestStudent': bestStudent,
      'worstStudent': worstStudent,
      'studentsCount': students.length,
    };
  }
}