import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/grades_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherGradesPage extends StatefulWidget {
  final String teacherId;

  const TeacherGradesPage({
    super.key,
    required this.teacherId,
  });

  @override
  State<TeacherGradesPage> createState() => _TeacherGradesPageState();
}

class _TeacherGradesPageState extends State<TeacherGradesPage> {
  final GradesService _gradesService = GradesService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Данные учителя
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  
  // Выбранные значения
  String? _selectedClassId;
  String? _selectedSubjectId;
  String _selectedClassName = '';
  String _selectedSubjectName = '';
  
  // Таблица оценок
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _grades = [];
  
  bool _isLoading = true;
  bool _loadingTable = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);

    try {
      print('👨‍🏫 Загрузка данных учителя: ${widget.teacherId}');
      
      // 1. Загружаем классы учителя
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (teacherDoc.exists) {
        final teacherData = teacherDoc.data()!;
        final classIds = List<String>.from(teacherData['classIds'] ?? []);
        
        print('📋 Классы учителя: $classIds');

        if (classIds.isNotEmpty) {
          // Загружаем информацию о классах
          for (final classId in classIds) {
            final classDoc = await _firestore
                .collection('classes')
                .doc(classId)
                .get();
                
            if (classDoc.exists) {
              final classData = classDoc.data()!;
              _classes.add({
                'classId': classId,
                'name': classData['name'] ?? 'Без названия',
              });
            }
          }
          
          // Выбираем первый класс по умолчанию
          if (_classes.isNotEmpty) {
            _selectedClassId = _classes.first['classId'];
            _selectedClassName = _classes.first['name'];
          }
        }
      }

      // 2. Загружаем предметы учителя
      _subjects = await _gradesService.getTeacherSubjects(widget.teacherId);
      print('📚 Всех предметов учителя: ${_subjects.length}');

    } catch (e) {
      print('❌ Ошибка загрузки: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClassSubjects() async {
    if (_selectedClassId == null) return;

    // Фильтруем предметы для выбранного класса
    final classSubjects = _subjects
        .where((subject) => subject['classId'] == _selectedClassId)
        .toList();
    
    if (classSubjects.isNotEmpty) {
      _selectedSubjectId = classSubjects.first['subjectId'];
      _selectedSubjectName = classSubjects.first['name'];
      await _loadGradesTable();
    } else {
      setState(() {
        _selectedSubjectId = null;
        _selectedSubjectName = '';
        _students = [];
        _grades = [];
      });
    }
  }

  Future<void> _loadGradesTable() async {
    if (_selectedClassId == null || _selectedSubjectId == null) return;

    setState(() => _loadingTable = true);

    try {
      _students = await _gradesService.getClassStudents(_selectedClassId!);
      print('👥 Всех учеников в классе: ${_students.length}');

      final gradesData = await _gradesService.getClassGrades(
        _selectedClassId!, 
        _selectedSubjectId!
      );

      final studentsWithGrades = (gradesData['students'] as List).cast<Map<String, dynamic>>();
      print('📊 Учеников с оценками: ${studentsWithGrades.length}');

      // Создаем объединенный список
      final Map<String, Map<String, dynamic>> gradesMap = {};
      
      for (final studentGrade in studentsWithGrades) {
        gradesMap[studentGrade['studentId']] = studentGrade;
      }

      // Формируем итоговый список _grades, включая тех, у кого нет оценок
      _grades = [];
      
      for (final student in _students) {
        final studentId = student['studentId'];
        
        if (gradesMap.containsKey(studentId)) {
          // Ученик с оценками
          _grades.add(gradesMap[studentId]!);
        } else {
          // Ученик без оценок
          _grades.add({
            'studentId': studentId,
            'studentName': student['fullName'],
            'grades': [],
            'average': 0.0,
          });
        }
      }

      print('✅ Итоговый список: ${_grades.length} учеников');

    } catch (e) {
      print('❌ Ошибка загрузки таблицы: $e');
    } finally {
      setState(() => _loadingTable = false);
    }
  }

  Widget _buildClassSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.green[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Класс:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: _selectedClassId,
            isExpanded: true,
            hint: const Text('Выберите класс'),
            items: _classes.map((classData) {
              return DropdownMenuItem<String>(
                value: classData['classId'],
                child: Text(classData['name']),
              );
            }).toList(),
            onChanged: (String? newValue) async {
              if (newValue != null) {
                setState(() {
                  _selectedClassId = newValue;
                  _selectedClassName = _classes
                      .firstWhere((c) => c['classId'] == newValue)['name'];
                  _selectedSubjectId = null;
                  _selectedSubjectName = '';
                  _students = [];
                  _grades = [];
                });
                await _loadClassSubjects();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    if (_selectedClassId == null) return const SizedBox.shrink();

    final classSubjects = _subjects
        .where((subject) => subject['classId'] == _selectedClassId)
        .toList();

    if (classSubjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.orange[50],
        child: const Text(
          'Нет предметов для этого класса',
          style: TextStyle(color: Colors.orange),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Предмет:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: _selectedSubjectId,
            isExpanded: true,
            hint: const Text('Выберите предмет'),
            items: classSubjects.map((subject) {
              return DropdownMenuItem<String>(
                value: subject['subjectId'],
                child: Text(subject['name']),
              );
            }).toList(),
            onChanged: (String? newValue) async {
              if (newValue != null) {
                setState(() {
                  _selectedSubjectId = newValue;
                  _selectedSubjectName = classSubjects
                      .firstWhere((s) => s['subjectId'] == newValue)['name'];
                });
                await _loadGradesTable();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    if (_selectedClassId == null || _selectedSubjectId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Класс: $_selectedClassName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Предмет: $_selectedSubjectName'),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGradesTable,
            tooltip: 'Обновить оценки',
          ),
        ],
      ),
    );
  }

  Widget _buildGradesTable() {
    if (_selectedClassId == null || _selectedSubjectId == null) {
      return const Center(
        child: Text('Выберите класс и предмет'),
      );
    }

    if (_loadingTable) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return const Center(
        child: Text('В классе нет учеников'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.green[100]!,
          ),
          columns: const [
            DataColumn(
              label: SizedBox(
                width: 200,
                child: Text('Ученик'),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 150,
                child: Text('Оценки'),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 80,
                child: Text('Средний'),
              ),
              numeric: true,
            ),
            DataColumn(
              label: SizedBox(
                width: 60,
                child: Text('Добавить'),
              ),
            ),
          ],
          rows: _grades.map((studentGrade) {
            final studentId = studentGrade['studentId'];
            final studentName = studentGrade['studentName'] as String;
            final grades = (studentGrade['grades'] as List).cast<Map<String, dynamic>>();
            final average = studentGrade['average'] ?? 0.0;

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      studentName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () => _viewStudentGrades(studentGrade),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Wrap(
                      spacing: 4,
                      children: grades.map((grade) {
                        return GestureDetector(
                          onTap: () => _addOrEditGradeDialog(studentGrade, grade),
                          child: Chip(
                            label: Text(
                              grade['value'].toString(),
                              style: TextStyle(
                                color: _getGradeColor(grade['value'] as int),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: _getGradeColor(grade['value'] as int).withOpacity(0.1),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    width: 80,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _getAverageColor(average).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: average > 0 ? Border.all(color: _getAverageColor(average)) : null,
                    ),
                    child: Text(
                      average > 0 ? average.toStringAsFixed(1) : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: average > 0 ? 16 : 14,
                        color: average > 0 ? _getAverageColor(average) : Colors.grey,
                      ),
                    ),
                  ),
                  onTap: () => _viewStudentGrades(studentGrade),
                ),
                DataCell(
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: const Icon(Icons.add, size: 20, color: Colors.green),
                      onPressed: () => _addOrEditGradeDialog(studentGrade, {}),
                      tooltip: 'Добавить оценку',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _viewStudentGrades(Map<String, dynamic> student) async {
    if (_selectedSubjectId == null) return;

    final gradesData = await _gradesService.getStudentGrades(
      student['studentId'],
      _selectedSubjectId!,
    );

    if (gradesData == null) {
      _showError('У ученика пока нет оценок');
      return;
    }

    final grades = (gradesData['grades'] as List).cast<Map<String, dynamic>>();
    final average = gradesData['average'] ?? 0.0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Оценки'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Предмет: $_selectedSubjectName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Средний балл: ${average.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  color: _getAverageColor(average),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (grades.isEmpty)
                const Text('Нет оценок', style: TextStyle(color: Colors.grey))
              else
                ...grades.map((grade) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getGradeColor(grade['value'] as int),
                        child: Text(
                          grade['value'].toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(_getGradeType(grade['type'])),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (grade['comment'] != null && (grade['comment'] as String).isNotEmpty)
                            Text(grade['comment'] as String),
                          Text(_formatDateFullFromTimestamp(grade['date']), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => _deleteGradeDialog(student, grade),
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addOrEditGradeDialog(student, {});
            },
            child: const Text('Добавить оценку'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGradeDialog(Map<String, dynamic> student, Map<String, dynamic> grade) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить оценку?'),
        content: Text('Вы уверены, что хотите удалить оценку ${grade['value']} у ${student['fullName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Найти индекс оценки
                final gradesData = await _gradesService.getStudentGrades(
                  student['studentId'],
                  _selectedSubjectId!,
                );

                if (gradesData != null) {
                  final grades = List<Map<String, dynamic>>.from(gradesData['grades']);
                  final index = grades.indexWhere((g) => 
                    g['value'] == grade['value'] && 
                    g['date'] == grade['date']
                  );

                  if (index != -1) {
                    await _gradesService.deleteGrade(
                      studentId: student['studentId'],
                      subjectId: _selectedSubjectId!,
                      gradeIndex: index,
                    );

                    Navigator.pop(context); 
                    Navigator.pop(context);
                    await _loadGradesTable();
                    
                    _showSuccess('Оценка удалена');
                  }
                }
              } catch (e) {
                _showError('Ошибка: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditGradeDialog(
    Map<String, dynamic> studentGrade, 
    Map<String, dynamic> existingGrade
  ) async {
    final studentId = studentGrade['studentId'];
    final studentName = studentGrade['studentName'] as String;
    
    final gradeController = TextEditingController(
      text: existingGrade.isNotEmpty ? existingGrade['value']?.toString() ?? '' : ''
    );
    
    final commentController = TextEditingController(
      text: existingGrade.isNotEmpty ? existingGrade['comment']?.toString() ?? '' : ''
    );
    
    String selectedType = existingGrade.isNotEmpty ? existingGrade['type'] ?? 'lesson' : 'lesson';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existingGrade.isEmpty 
            ? 'Добавить оценку для $studentName' 
            : 'Изменить оценку'
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Предмет: $_selectedSubjectName',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Тип работы',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'lesson',
                    child: Row(
                      children: [
                        Icon(Icons.school, size: 18),
                        SizedBox(width: 8),
                        Text('Урок'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'homework',
                    child: Row(
                      children: [
                        Icon(Icons.assignment, size: 18),
                        SizedBox(width: 8),
                        Text('Домашняя работа'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'test',
                    child: Row(
                      children: [
                        Icon(Icons.quiz, size: 18),
                        SizedBox(width: 8),
                        Text('Контрольная работа'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedType = value;
                  }
                },
              ),
              
              const SizedBox(height: 12),
              
              TextField(
                controller: gradeController,
                decoration: const InputDecoration(
                  labelText: 'Оценка (1-5)',
                  hintText: '5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grade),
                ),
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 12),
              
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          if (existingGrade.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                try {
                  final grades = (studentGrade['grades'] as List).cast<Map<String, dynamic>>();
                  final index = grades.indexOf(existingGrade);
                  
                  if (index != -1) {
                    await _gradesService.deleteGrade(
                      studentId: studentId,
                      subjectId: _selectedSubjectId!,
                      gradeIndex: index,
                    );
                    
                    Navigator.pop(context);
                    await _loadGradesTable();
                    _showSuccess('Оценка удалена');
                  }
                } catch (e) {
                  _showError('Ошибка удаления: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 18),
                  SizedBox(width: 4),
                  Text('Удалить'),
                ],
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              final gradeText = gradeController.text.trim();
              if (gradeText.isEmpty) {
                _showError('Введите оценку');
                return;
              }

              final grade = int.tryParse(gradeText) ?? 0;
              if (grade < 1 || grade > 5) {
                _showError('Оценка должна быть от 1 до 5');
                return;
              }

              try {
                // Находим полные данные студента в списке _students
                final fullStudent = _students.firstWhere(
                  (s) => s['studentId'] == studentId,
                  orElse: () => studentGrade,
                );

                await _gradesService.addGrade(
                  studentId: studentId,
                  subjectId: _selectedSubjectId!,
                  subjectName: _selectedSubjectName,
                  studentName: fullStudent['fullName'] ?? studentName,
                  classId: _selectedClassId!,
                  grade: grade,
                  comment: commentController.text.trim(),
                  type: selectedType,
                );

                Navigator.pop(context);
                await _loadGradesTable();
                _showSuccess('Оценка ${existingGrade.isEmpty ? 'добавлена' : 'обновлена'}');
              } catch (e) {
                _showError('Ошибка сохранения: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(existingGrade.isEmpty ? Icons.add : Icons.save, size: 18),
                const SizedBox(width: 4),
                Text(existingGrade.isEmpty ? 'Добавить' : 'Сохранить'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(int grade) {
    if (grade == 5) return Colors.green;
    if (grade == 4) return Colors.blue;
    if (grade == 3) return Colors.orange;
    if (grade == 2) return Colors.red;
    return Colors.red[900]!;
  }

  Color _getAverageColor(double average) {
    if (average >= 4.5) return Colors.green;
    if (average >= 3.5) return Colors.blue;
    if (average >= 2.5) return Colors.orange;
    return Colors.red;
  }

  String _getGradeType(String? type) {
    switch (type) {
      case 'lesson': return 'Урок';
      case 'homework': return 'Домашняя работа';
      case 'test': return 'Контрольная работа';
      default: return 'Урок';
    }
  }

  String _formatDateFullFromTimestamp(dynamic date) {
    if (date is Timestamp) {
      final d = date.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    return '';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал оценок'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeacherData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildClassSelector(),
                
                _buildSubjectSelector(),
                
                _buildTableHeader(),
                
                Expanded(
                  child: _buildGradesTable(),
                ),
              ],
            ),
    );
  }
}