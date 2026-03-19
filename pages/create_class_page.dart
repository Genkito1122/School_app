import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';

class CreateClassPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  const CreateClassPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
  });

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  String? _selectedTeacherId;
  List<Map<String, dynamic>> _availableTeachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableTeachers();
  }

  Future<void> _loadAvailableTeachers() async {
    try {
      final teachersSnapshot = await _firestore
          .collection('teachers')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() {
        _availableTeachers = teachersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['fullName'],
            'email': data['email'],
          };
        }).toList();
      });
    } catch (e) {
      print('Ошибка загрузки учителей: $e');
    }
  }

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите классного руководителя')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final classId = _firestore.collection('classes').doc().id;
      
      await _firestore.collection('classes').doc(classId).set({
        'classId': classId,
        'name': _classNameController.text.trim(),
        'schoolId': widget.schoolId,
        'schoolName': widget.schoolName,
        'teacherId': _selectedTeacherId,
        'studentIds': [],
        'studentCodes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('teachers').doc(_selectedTeacherId!).update({
        'classIds': FieldValue.arrayUnion([classId]),
      });

      final selectedTeacher = _availableTeachers.firstWhere(
        (teacher) => teacher['id'] == _selectedTeacherId
      );

      await _chatService.createClassChat(
        className: _classNameController.text.trim(),
        classId: classId,
        schoolId: widget.schoolId,
        teacherId: _selectedTeacherId!,
        teacherName: selectedTeacher['name'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Класс "${_classNameController.text}" создан!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка создания класса: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать новый класс'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView( 
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.school, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.schoolName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Создание нового класса',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  labelText: 'Название класса',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                  hintText: 'Например: 5А, 10Б, 11В',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите название класса';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Классный руководитель:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_availableTeachers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Нет доступных учителей',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTeacherId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Выберите классного руководителя'),
                    items: _availableTeachers.map((teacher) {
                      return DropdownMenuItem<String>(
                        value: teacher['id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(teacher['name']),
                            Text(
                              teacher['email'],
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTeacherId = newValue;
                      });
                    },
                  ),
                ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Создать класс',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }
}