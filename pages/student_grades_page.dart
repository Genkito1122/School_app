import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/grades_service.dart';

class StudentGradesPage extends StatefulWidget {
  const StudentGradesPage({super.key});

  @override
  State<StudentGradesPage> createState() => _StudentGradesPageState();
}

class _StudentGradesPageState extends State<StudentGradesPage> {
  final GradesService _gradesService = GradesService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _grades = [];
  String? _studentName;
  String? _className;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Определяем, кто смотрит: ученик или родитель
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'];

      String? targetStudentId;

      if (userRole == 'student') {
        targetStudentId = user.uid;
        
        // Получаем имя ученика
        final studentDoc = await _firestore.collection('students').doc(user.uid).get();
        if (studentDoc.exists) {
          setState(() {
            _studentName = studentDoc.data()?['fullName'];
            _className = studentDoc.data()?['className'];
          });
        }
      } else if (userRole == 'parent') {
        // Родитель смотрит оценки ребенка
        final parentDoc = await _firestore.collection('parents').doc(user.uid).get();
        if (parentDoc.exists) {
          final childIds = List<String>.from(parentDoc.data()?['childIds'] ?? []);
          if (childIds.isNotEmpty) {
            targetStudentId = childIds.first;
            
            final childDoc = await _firestore.collection('students').doc(childIds.first).get();
            if (childDoc.exists) {
              setState(() {
                _studentName = childDoc.data()?['fullName'];
                _className = childDoc.data()?['className'];
              });
            }
          }
        }
      }

      if (targetStudentId != null) {
        final grades = await _gradesService.getStudentAllGrades(targetStudentId);
        setState(() => _grades = grades);
      }
    } catch (e) {
      print('❌ Ошибка загрузки оценок: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
     }
    }
  }

  Widget _buildGradesList() {
    if (_grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grade, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Нет оценок', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              _studentName ?? 'Ученик',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              _className ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _grades.length,
      itemBuilder: (context, index) {
        final subject = _grades[index];
        final grades = List<Map<String, dynamic>>.from(subject['grades'] ?? []);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок предмета
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getAverageColor(subject['average'] as double),
                      child: Text(
                        subject['average'].toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject['subjectName'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Учитель: ${subject['teacherName']}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Оценки
                if (grades.isEmpty)
                  const Text(
                    'Нет оценок по этому предмету',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Оценки:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      
                      // Список оценок в виде карточек
                      ...grades.map((grade) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.grey[50],
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                // Оценка
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getGradeColor(grade['value'] as int).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getGradeColor(grade['value'] as int),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      grade['value'].toString(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _getGradeColor(grade['value'] as int),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Информация об оценке
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGradeType(grade['type']),
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      if (grade['comment'] != null && (grade['comment'] as String).isNotEmpty)
                                        Text(
                                          grade['comment'] as String,
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                // Дата
                                Text(
                                  _formatDate(grade['date']),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final d = date.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои оценки'),
        backgroundColor: Colors.blue,
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
          : _buildGradesList(),
    );
  }
}