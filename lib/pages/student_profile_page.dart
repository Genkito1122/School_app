import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/grades_service.dart';
import 'package:school_app/services/homework_service.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/pages/chat_detail_page.dart';

class StudentProfilePage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;
  final String className;

  const StudentProfilePage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GradesService _gradesService = GradesService();
  final HomeworkService _homeworkService = HomeworkService();
  final ChatService _chatService = ChatService();

  late TabController _tabController;
  
  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _homeworks = [];
  List<Map<String, dynamic>> _parents = [];
  
  bool _isLoading = true;
  double _overallAverage = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Загружаем данные ученика
      final studentDoc = await _firestore.collection('students').doc(widget.studentId).get();
      if (studentDoc.exists) {
        _studentData = studentDoc.data();
      }

      // Загружаем оценки
      _grades = await _gradesService.getStudentAllGrades(widget.studentId);
      
      // Считаем общий средний балл
      if (_grades.isNotEmpty) {
        double total = 0;
        for (final subject in _grades) {
          total += (subject['average'] as double?) ?? 0;
        }
        _overallAverage = total / _grades.length;
      }

      // Загружаем ДЗ
      _homeworks = await _homeworkService.getStudentHomeworks(widget.studentId);

      // Загружаем родителей
      final parentIds = List<String>.from(_studentData?['parentIds'] ?? []);
      for (final parentId in parentIds) {
        final parentDoc = await _firestore.collection('parents').doc(parentId).get();
        if (parentDoc.exists) {
          _parents.add({
            'uid': parentId,
            'fullName': parentDoc.data()?['fullName'] ?? 'Неизвестно',
            'phone': parentDoc.data()?['phone'] ?? 'Не указан',
            'email': parentDoc.data()?['email'] ?? '',
          });
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки профиля: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessageToParent(Map<String, dynamic> parent) async {
    try {
      final userInfo = await _chatService.getUserInfoForMessage();
      
      final chatId = await _chatService.createOrGetPersonalChat(
        otherUserId: parent['uid'],
        otherUserName: parent['fullName'],
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatId,
              chatName: parent['fullName'],
              chatType: 'personal',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Color _getGradeColor(int grade) {
    if (grade == 5) return Colors.green;
    if (grade == 4) return Colors.blue;
    if (grade == 3) return Colors.orange;
    return Colors.red;
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
      case 'homework': return 'ДЗ';
      case 'test': return 'Контр.';
      default: return 'Урок';
    }
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final d = date.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Профиль'),
            Tab(icon: Icon(Icons.grade), text: 'Оценки'),
            Tab(icon: Icon(Icons.assignment), text: 'ДЗ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildGradesTab(),
                _buildHomeworkTab(),
              ],
            ),
    );
  }

  // ==================== ВКЛАДКА ПРОФИЛЯ ====================
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Аватар и основная информация
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.blue,
                    child: Text(
                      widget.studentName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 36, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.studentName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.className,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getAverageColor(_overallAverage).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getAverageColor(_overallAverage)),
                    ),
                    child: Text(
                      'Средний балл: ${_overallAverage.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getAverageColor(_overallAverage),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Основная информация
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Основная информация',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email, 'Email', _studentData?['email'] ?? 'Не указан'),
                  const Divider(),
                  _buildInfoRow(Icons.cake, 'Дата рождения', _studentData?['birthDate'] ?? 'Не указана'),
                  const Divider(),
                  _buildInfoRow(Icons.school, 'Школа', _studentData?['schoolName'] ?? 'Не указана'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Родители
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Родители',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_parents.isEmpty)
                    const Text('Нет привязанных родителей', style: TextStyle(color: Colors.grey))
                  else
                    ..._parents.map((parent) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.orange[50],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            (parent['fullName'] as String).substring(0, 1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(parent['fullName']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📞 ${parent['phone']}'),
                            if (parent['email'].isNotEmpty)
                              Text('📧 ${parent['email']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue),
                          onPressed: () => _sendMessageToParent(parent),
                          tooltip: 'Написать родителю',
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // ==================== ВКЛАДКА ОЦЕНОК ====================
  Widget _buildGradesTab() {
    if (_grades.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет оценок', style: TextStyle(fontSize: 18, color: Colors.grey)),
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
        final average = subject['average'] as double? ?? 0;
        
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
                      backgroundColor: _getAverageColor(average),
                      child: Text(
                        average.toStringAsFixed(1),
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
                    Chip(label: Text('${grades.length} оценок')),
                  ],
                ),
                
                if (grades.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: grades.map((grade) {
                      final value = grade['value'] as int;
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getGradeColor(value).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getGradeColor(value), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getGradeColor(value),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== ВКЛАДКА ДЗ ====================
  Widget _buildHomeworkTab() {
    if (_homeworks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет домашних заданий', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _homeworks.length,
      itemBuilder: (context, index) {
        final hw = _homeworks[index];
        final deadline = (hw['deadline'] as Timestamp).toDate();
        final isOverdue = hw['isOverdue'] as bool;
        final daysLeft = hw['daysLeft'] as int;
        
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
            title: Text(hw['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${hw['subjectName']} • ${hw['teacherName']}'),
                Text(
                  'До: ${deadline.day}.${deadline.month}.${deadline.year}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.grey,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (!isOverdue)
                  Text('Осталось: $daysLeft д.', style: const TextStyle(fontSize: 12, color: Colors.green)),
                if (isOverdue)
                  const Text('Просрочено', style: TextStyle(fontSize: 12, color: Colors.red)),
              ],
            ),
          ),
        );
      },
    );
  }
}