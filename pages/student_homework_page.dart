import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/homework_service.dart';

class StudentHomeworkPage extends StatefulWidget {
  final String? studentId; 
  const StudentHomeworkPage({super.key, this.studentId});

  @override
  State<StudentHomeworkPage> createState() => _StudentHomeworkPageState();
}

class _StudentHomeworkPageState extends State<StudentHomeworkPage> {
  final HomeworkService _homeworkService = HomeworkService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _homeworks = [];
  String? _studentName;
  String? _className;
  bool _isLoading = true;
  String? _filterSubjectId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
  final user = _auth.currentUser;
  if (user == null) return;

  print('🔄 StudentHomeworkPage._loadData() для пользователя: ${user.uid}');
  
  try {
    // Определяем, кто смотрит: ученик или родитель
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userRole = userDoc.data()?['role'];
    
    print('🎭 Роль пользователя: $userRole');

    String? targetStudentId;
    String? studentClassId;

    if (userRole == 'student') {
      targetStudentId = user.uid;
      print('👤 Смотрим ДЗ самого ученика ID: $targetStudentId');
      
      // Получаем данные ученика
      final studentDoc = await _firestore.collection('students').doc(user.uid).get();
      if (studentDoc.exists) {
        final studentData = studentDoc.data()!;
        studentClassId = studentData['classId'] as String?;
        
        print('📚 Данные ученика:');
        print('  - classId: $studentClassId');
        print('  - fullName: ${studentData['fullName']}');
        print('  - className: ${studentData['className']}');
        
        if (mounted) {
          setState(() {
            _studentName = studentData['fullName'];
            _className = studentData['className'];
          });
        }
      } else {
        print('❌ Документ ученика не найден в коллекции students');
      }
    } else if (userRole == 'parent') {
      print('👪 Смотрим ДЗ ребенка как родитель');
      
      // Родитель смотрит ДЗ ребенка
      final parentDoc = await _firestore.collection('parents').doc(user.uid).get();
      if (parentDoc.exists) {
        final parentData = parentDoc.data()!;
        final childIds = List<String>.from(parentData['childIds'] ?? []);
        print('👶 ID детей: $childIds');
        
        if (childIds.isNotEmpty) {
          targetStudentId = childIds.first;
          print('🎯 Выбран ребенок: $targetStudentId');
          
          final childDoc = await _firestore.collection('students').doc(childIds.first).get();
          if (childDoc.exists) {
            final childData = childDoc.data()!;
            studentClassId = childData['classId'] as String?;
            
            print('📚 Данные ребенка:');
            print('  - classId: $studentClassId');
            print('  - fullName: ${childData['fullName']}');
            print('  - className: ${childData['className']}');
            
            if (mounted) {
              setState(() {
                _studentName = childData['fullName'];
                _className = childData['className'];
              });
            }
          } else {
            print('❌ Документ ребенка не найден');
          }
        } else {
          print('⚠️ У родителя нет детей');
        }
      } else {
        print('❌ Документ родителя не найден');
      }
    }

    if (targetStudentId != null) {
      print('🎯 Получаем ДЗ для ученика ID: $targetStudentId, classId: $studentClassId');
      
      // ДИРЕКТНЫЙ ЗАПРОС К FIRESTORE для проверки
      final directQuery = await _firestore
          .collection('homeworks')
          .where('classId', isEqualTo: studentClassId)
          .where('isActive', isEqualTo: true)
          .get();
      
      print('🔍 Прямой запрос Firestore:');
      print('  - classId для запроса: $studentClassId');
      print('  - Найдено документов: ${directQuery.docs.length}');
      
      if (directQuery.docs.isNotEmpty) {
        for (var doc in directQuery.docs) {
          print('  📝 ДЗ: ${doc.id}');
          print('     - title: ${doc.data()['title']}');
          print('     - subjectName: ${doc.data()['subjectName']}');
          print('     - classId: ${doc.data()['classId']}');
          print('     - className: ${doc.data()['className']}');
          print('     - deadline: ${doc.data()['deadline']}');
          print('     - isActive: ${doc.data()['isActive']}');
        }
      } else {
        print('⚠️ В Firestore не найдено ДЗ для этого класса');
        
        // Проверим, есть ли вообще ДЗ в системе
        final allHomeworks = await _firestore.collection('homeworks').limit(5).get();
        print('🔍 Всего ДЗ в системе: ${allHomeworks.docs.length}');
        for (var doc in allHomeworks.docs) {
          print('  📦 ДЗ ${doc.id}: classId=${doc.data()['classId']}, isActive=${doc.data()['isActive']}');
        }
      }
      
      // Теперь через сервис
      final homeworks = await _homeworkService.getStudentHomeworks(targetStudentId);
      print('📝 Получено ДЗ через сервис: ${homeworks.length}');
      
      if (mounted) {
        setState(() => _homeworks = homeworks);
      }
    } else {
      print('⚠️ Не удалось определить ученика для загрузки ДЗ');
    }
  } catch (e) {
    print('❌ Ошибка загрузки ДЗ: $e');
    print('Stack trace: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  List<Map<String, dynamic>> _getFilteredHomeworks() {
    if (_filterSubjectId == null) {
      return _homeworks;
    }
    
    return _homeworks
        .where((hw) => hw['subjectId'] == _filterSubjectId)
        .toList();
  }

  List<String> _getUniqueSubjects() {
    final subjects = <String, String>{};
    
    for (final hw in _homeworks) {
      final subjectId = hw['subjectId'] as String;
      final subjectName = hw['subjectName'] as String;
      subjects[subjectId] = subjectName;
    }
    
    return subjects.keys.toList();
  }

  Widget _buildHomeworkList() {
    final filteredHomeworks = _getFilteredHomeworks();
    
    if (filteredHomeworks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Нет домашних заданий', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              _studentName ?? 'Ученик',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              _className ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Фильтр по предметам
        if (_getUniqueSubjects().length > 1)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 16),
                const SizedBox(width: 8),
                const Text('Фильтр:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _filterSubjectId,
                    isExpanded: true,
                    hint: const Text('Все предметы'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Все предметы'),
                      ),
                      ..._getUniqueSubjects().map((subjectId) {
                        final hw = filteredHomeworks.firstWhere(
                          (hw) => hw['subjectId'] == subjectId,
                        );
                        return DropdownMenuItem<String>(
                          value: subjectId,
                          child: Text(hw['subjectName'] as String),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _filterSubjectId = value);
                    },
                  ),
                ),
              ],
            ),
          ),

        // Статистика
        Card(
          margin: const EdgeInsets.all(8),
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Всего ДЗ', filteredHomeworks.length.toString(), Icons.assignment),
              ],
            ),
          ),
        ),

        // Список ДЗ
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredHomeworks.length,
            itemBuilder: (context, index) {
              final homework = filteredHomeworks[index];
              final deadline = (homework['deadline'] as Timestamp).toDate();
              final isOverdue = homework['isOverdue'] as bool;
              final daysLeft = homework['daysLeft'] as int;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOverdue ? Colors.red : Colors.orange,
                    child: Icon(
                      isOverdue ? Icons.warning : Icons.assignment,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(homework['title']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${homework['subjectName']} • ${homework['teacherName']}'),
                      Text(
                        'До: ${deadline.day}.${deadline.month}.${deadline.year}',
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.grey,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (!isOverdue)
                        Text('Осталось дней: $daysLeft', style: const TextStyle(fontSize: 12, color: Colors.green)),
                      if (isOverdue)
                        Text('Просрочено', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _viewHomeworkDetails(homework),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  String _getNearestDeadline(List<Map<String, dynamic>> homeworks) {
    if (homeworks.isEmpty) return '-';
    
    // Сортируем по дедлайну
    homeworks.sort((a, b) {
      final deadlineA = (a['deadline'] as Timestamp).toDate();
      final deadlineB = (b['deadline'] as Timestamp).toDate();
      return deadlineA.compareTo(deadlineB);
    });
    
    final nearest = homeworks.first;
    final deadline = (nearest['deadline'] as Timestamp).toDate();
    final daysLeft = nearest['daysLeft'] as int;
    
    if (nearest['isOverdue'] as bool) {
      return 'Просрочено';
    }
    
    return '$daysLeft д.';
  }

  Future<void> _viewHomeworkDetails(Map<String, dynamic> homework) async {
    final deadline = (homework['deadline'] as Timestamp).toDate();
    final isOverdue = homework['isOverdue'] as bool;
    final daysLeft = homework['daysLeft'] as int;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(homework['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Предмет: ${homework['subjectName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Учитель: ${homework['teacherName']}'),
              Text('Класс: ${homework['className']}'),
              const SizedBox(height: 12),
              const Divider(),
              const Text('Задание:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(homework['description']),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: isOverdue ? Colors.red : Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Дедлайн: ${deadline.day}.${deadline.month}.${deadline.year}',
                    style: TextStyle(color: isOverdue ? Colors.red : Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!isOverdue)
                Text('Осталось дней: $daysLeft', style: const TextStyle(color: Colors.green)),
              if (isOverdue)
                Text('Просрочено', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'ДЗ автоматически удалится после дедлайна',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Домашние задания'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildHomeworkList(),
    );
  }
}