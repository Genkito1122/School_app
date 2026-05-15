import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/pages/student_profile_page.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/pages/chat_detail_page.dart';

class ClassStudentsPage extends StatefulWidget {
  final String classId;
  final String className;

  const ClassStudentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassStudentsPage> createState() => _ClassStudentsPageState();
}

class _ClassStudentsPageState extends State<ClassStudentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: widget.classId)
          .orderBy('fullName')
          .get();

      setState(() {
        _students = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'fullName': data['fullName'] ?? 'Неизвестно',
            'email': data['email'] ?? '',
            'birthDate': data['birthDate'] ?? '',
            'parentIds': List<String>.from(data['parentIds'] ?? []),
          };
        }).toList();
      });
    } catch (e) {
      print('❌ Ошибка загрузки учеников: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getParentCount(String studentId) async {
    final doc = await _firestore.collection('students').doc(studentId).get();
    final parentIds = List<String>.from(doc.data()?['parentIds'] ?? []);
    return parentIds.length;
  }

  void _openStudentProfile(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentProfilePage(
          studentId: student['uid'],
          studentName: student['fullName'],
          classId: widget.classId,
          className: widget.className,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} — ученики'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Нет учеников', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            (student['fullName'] as String).substring(0, 1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          student['fullName'],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (student['email'].isNotEmpty)
                              Text(student['email'], style: const TextStyle(fontSize: 12)),
                            FutureBuilder<int>(
                              future: _getParentCount(student['uid']),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  'Родителей: $count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: count > 0 ? Colors.green : Colors.orange,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _openStudentProfile(student),
                      ),
                    );
                  },
                ),
    );
  }
}