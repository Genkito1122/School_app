import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/grades_service.dart';

class StudentGradesPage extends StatefulWidget {
  final String? childId;
  const StudentGradesPage({super.key, this.childId});

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
  
  // Для переключения между детьми
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildId;
  bool _isParent = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'];

      if (userRole == 'student') {
        await _loadStudentData(user.uid);
      } else if (userRole == 'parent') {
        _isParent = true;
        await _loadParentData(user.uid);
      }
    } catch (e) {
      print('❌ Ошибка загрузки оценок: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentData(String studentId) async {
    final studentDoc = await _firestore.collection('students').doc(studentId).get();
    if (studentDoc.exists) {
      setState(() {
        _studentName = studentDoc.data()?['fullName'];
        _className = studentDoc.data()?['className'];
      });
      await _loadGrades(studentId);
    }
  }

  Future<void> _loadParentData(String parentId) async {
    final parentDoc = await _firestore.collection('parents').doc(parentId).get();
    if (parentDoc.exists) {
      final childIds = List<String>.from(parentDoc.data()?['childIds'] ?? []);
      
      if (childIds.isEmpty) return;
      
      // Загружаем имена всех детей
      List<Map<String, dynamic>> childrenList = [];
      for (final childId in childIds) {
        final childDoc = await _firestore.collection('students').doc(childId).get();
        if (childDoc.exists) {
          childrenList.add({
            'uid': childId,
            'fullName': childDoc.data()?['fullName'] ?? 'Неизвестно',
            'className': childDoc.data()?['className'] ?? '',
          });
        }
      }
      
      // Выбираем переданного ребёнка или первого
      String? activeChildId = widget.childId ?? (childrenList.isNotEmpty ? childrenList.first['uid'] : null);
      
      setState(() {
        _children = childrenList;
        _selectedChildId = activeChildId;
      });
      
      if (activeChildId != null) {
        final selectedChild = childrenList.firstWhere(
          (c) => c['uid'] == activeChildId,
          orElse: () => childrenList.first,
        );
        setState(() {
          _studentName = selectedChild['fullName'];
          _className = selectedChild['className'];
        });
        await _loadGrades(activeChildId);
      }
    }
  }

  Future<void> _loadGrades(String studentId) async {
    final grades = await _gradesService.getStudentAllGrades(studentId);
    setState(() => _grades = grades);
  }

  Future<void> _switchChild(String newChildId) async {
    setState(() => _isLoading = true);
    
    final child = _children.firstWhere((c) => c['uid'] == newChildId);
    _selectedChildId = newChildId;
    _studentName = child['fullName'];
    _className = child['className'];
    _grades = [];
    
    await _loadGrades(newChildId);
    setState(() => _isLoading = false);
  }

  Widget _buildChildSelector() {
    if (!_isParent || _children.length <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Text('Ребёнок:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButton<String>(
                value: _selectedChildId,
                isExpanded: true,
                underline: const SizedBox(),
                items: _children.map((child) {
                  return DropdownMenuItem<String>(
                    value: child['uid'],
                    child: Text(
                      '${child['fullName']} (${child['className']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _selectedChildId) {
                    _switchChild(newValue);
                  }
                },
              ),
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

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final d = date.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    }
    return '';
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
            Text(_studentName ?? 'Ученик', style: const TextStyle(color: Colors.grey)),
            Text(_className ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
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
                  
                  if (grades.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Оценки:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...grades.map((grade) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.grey[50],
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_studentName ?? 'Оценки'),
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
          : Column(
              children: [
                _buildChildSelector(),
                Expanded(child: _buildGradesList()),
              ],
            ),
    );
  }
}