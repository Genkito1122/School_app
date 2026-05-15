import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/homework_service.dart';

class StudentHomeworkPage extends StatefulWidget {
  final String? childId;
  const StudentHomeworkPage({super.key, this.childId});

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
      print('❌ Ошибка загрузки ДЗ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentData(String studentId) async {
    final studentDoc = await _firestore.collection('students').doc(studentId).get();
    if (studentDoc.exists) {
      final studentData = studentDoc.data()!;
      setState(() {
        _studentName = studentData['fullName'];
        _className = studentData['className'];
      });
      await _loadHomeworks(studentId);
    }
  }

  Future<void> _loadParentData(String parentId) async {
    final parentDoc = await _firestore.collection('parents').doc(parentId).get();
    if (parentDoc.exists) {
      final childIds = List<String>.from(parentDoc.data()?['childIds'] ?? []);
      
      if (childIds.isEmpty) return;
      
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
        await _loadHomeworks(activeChildId);
      }
    }
  }

  Future<void> _loadHomeworks(String studentId) async {
    final homeworks = await _homeworkService.getStudentHomeworks(studentId);
    setState(() => _homeworks = homeworks);
  }

  Future<void> _switchChild(String newChildId) async {
    setState(() => _isLoading = true);
    
    final child = _children.firstWhere((c) => c['uid'] == newChildId);
    _selectedChildId = newChildId;
    _studentName = child['fullName'];
    _className = child['className'];
    _homeworks = [];
    _filterSubjectId = null;
    
    await _loadHomeworks(newChildId);
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

  List<Map<String, dynamic>> _getFilteredHomeworks() {
    if (_filterSubjectId == null) return _homeworks;
    return _homeworks.where((hw) => hw['subjectId'] == _filterSubjectId).toList();
  }

  List<String> _getUniqueSubjects() {
    final subjects = <String, String>{};
    for (final hw in _homeworks) {
      subjects[hw['subjectId'] as String] = hw['subjectName'] as String;
    }
    return subjects.keys.toList();
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
    
    final sorted = List<Map<String, dynamic>>.from(homeworks);
    sorted.sort((a, b) {
      final aDate = (a['deadline'] as Timestamp).toDate();
      final bDate = (b['deadline'] as Timestamp).toDate();
      return aDate.compareTo(bDate);
    });
    
    final nearest = sorted.first;
    if (nearest['isOverdue'] as bool) return 'Просрочено';
    return '${nearest['daysLeft']} д.';
  }

  Widget _buildHomeworkList() {
    final filtered = _getFilteredHomeworks();
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Нет домашних заданий', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(_studentName ?? 'Ученик', style: const TextStyle(color: Colors.grey)),
            Text(_className ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: Column(
        children: [
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
                        const DropdownMenuItem<String>(value: null, child: Text('Все предметы')),
                        ..._getUniqueSubjects().map((id) {
                          final hw = filtered.firstWhere((h) => h['subjectId'] == id);
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(hw['subjectName'] as String),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _filterSubjectId = v),
                    ),
                  ),
                ],
              ),
            ),

          Card(
            margin: const EdgeInsets.all(8),
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Всего ДЗ', filtered.length.toString(), Icons.assignment),
                  _buildStatItem('Ближайший дедлайн', _getNearestDeadline(filtered), Icons.access_time),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final hw = filtered[index];
                final deadline = (hw['deadline'] as Timestamp).toDate();
                final isOverdue = hw['isOverdue'] as bool;
                final daysLeft = hw['daysLeft'] as int;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOverdue ? Colors.red : Colors.orange,
                      child: Icon(isOverdue ? Icons.warning : Icons.assignment, color: Colors.white),
                    ),
                    title: Text(hw['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${hw['subjectName']} • ${hw['teacherName']}'),
                        Text(
                          'До: ${deadline.day}.${deadline.month}.${deadline.year}',
                          style: TextStyle(color: isOverdue ? Colors.red : Colors.grey),
                        ),
                        if (!isOverdue)
                          Text('Осталось: $daysLeft д.', style: const TextStyle(fontSize: 12, color: Colors.green)),
                        if (isOverdue)
                          const Text('Просрочено', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _viewHomeworkDetails(hw),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewHomeworkDetails(Map<String, dynamic> hw) async {
    final deadline = (hw['deadline'] as Timestamp).toDate();
    final isOverdue = hw['isOverdue'] as bool;
    final daysLeft = hw['daysLeft'] as int;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hw['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Предмет: ${hw['subjectName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Учитель: ${hw['teacherName']}'),
              Text('Класс: ${hw['className']}'),
              const SizedBox(height: 12),
              const Divider(),
              const Text('Задание:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(hw['description']),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: isOverdue ? Colors.red : Colors.orange),
                  const SizedBox(width: 8),
                  Text('Дедлайн: ${deadline.day}.${deadline.month}.${deadline.year}'),
                ],
              ),
              if (!isOverdue)
                Text('Осталось дней: $daysLeft', style: const TextStyle(color: Colors.green)),
              if (isOverdue)
                const Text('Просрочено', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_studentName ?? 'Домашние задания'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Обновить'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildChildSelector(),
                Expanded(child: _buildHomeworkList()),
              ],
            ),
    );
  }
}