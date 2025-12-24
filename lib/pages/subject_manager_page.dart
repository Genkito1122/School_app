import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/subjects_service.dart';

class SubjectsManagerPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  const SubjectsManagerPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
  });

  @override
  State<SubjectsManagerPage> createState() => _SubjectsManagerPageState();
}

class _SubjectsManagerPageState extends State<SubjectsManagerPage> with SingleTickerProviderStateMixin {
  final SubjectsService _subjectsService = SubjectsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  List<Map<String, dynamic>> _subjects = [];
  Map<String, List<Map<String, dynamic>>> _teachersBySubject = {};
  List<Map<String, dynamic>> _allTeachers = [];
  
  bool _isLoading = true;
  int _currentTab = 0; // 0 = предметы, 1 = назначения

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
  try {
    print('🔄 Загрузка данных для школы: ${widget.schoolId}');
    
    // 1. Загружаем предметы школы
    final subjects = await _subjectsService.getSchoolSubjects(widget.schoolId);
    print('📚 Загружено предметов: ${subjects.length}');
    
    if (!mounted) return;
    setState(() => _subjects = subjects);

    // 2. Загружаем всех учителей школы
    final teachersSnapshot = await _firestore
        .collection('teachers')
        .where('schoolId', isEqualTo: widget.schoolId)
        .get();

    print('👨‍🏫 Загружено учителей: ${teachersSnapshot.docs.length}');
    
    if (!mounted) return;
    setState(() {
      _allTeachers = teachersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'teacherId': doc.id,
          'fullName': data['fullName'] ?? 'Неизвестно',
          'email': data['email'] ?? '',
        };
      }).toList();
    });

    // 3. Загружаем учителей для каждого предмета
    print('🔄 Загрузка учителей для каждого предмета...');
    for (final subject in subjects) {
      if (!mounted) return;
      final teachers = await _subjectsService.getSubjectTeachers(subject['subjectId']);
      _teachersBySubject[subject['subjectId']] = teachers;
      print('  📝 ${subject['name']}: ${teachers.length} учителей');
    }

  } catch (e) {
    print('❌ Ошибка загрузки данных: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _addSubjectDialog() async {
  final subjectController = TextEditingController();

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Новый предмет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Название предмета',
                hintText: 'Математика, Русский язык...',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Предмет будет доступен для всех классов школы',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final subjectName = subjectController.text.trim();
              if (subjectName.isEmpty) {
                // Используем dialogContext, а не context из класса
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Введите название предмета')),
                );
                return;
              }

              try {
                await _subjectsService.createSubject(
                  schoolId: widget.schoolId,
                  subjectName: subjectName,
                );

                Navigator.pop(dialogContext); // Закрываем диалог
                
                // Обновляем данные
                if (mounted) {
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Предмет "$subjectName" создан'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // Если диалог еще открыт, показываем ошибку в нем
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      );
    },
  );
}

  Future<void> _assignTeacherDialog(String subjectId, String subjectName) async {
  final availableTeachers = await _subjectsService.getAvailableTeachersForSubject(
    widget.schoolId, 
    subjectId
  );

  if (availableTeachers.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных учителей')),
      );
    }
    return;
  }

  String? selectedTeacherId;

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Назначить учителя на "$subjectName"'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Выберите учителя:'),
                  const SizedBox(height: 12),
                  
                  if (availableTeachers.isEmpty)
                    const Text('Нет доступных учителей', style: TextStyle(color: Colors.grey))
                  else
                    ...availableTeachers.map((teacher) {
                      return RadioListTile<String>(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacher['fullName']),
                            Text(
                              teacher['email'],
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        value: teacher['teacherId'],
                        groupValue: selectedTeacherId,
                        onChanged: (value) => setState(() => selectedTeacherId = value),
                      );
                    }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: selectedTeacherId == null ? null : () async {
                  try {
                    await _subjectsService.assignTeacherToSubject(
                      subjectId: subjectId,
                      teacherId: selectedTeacherId!,
                      schoolId: widget.schoolId,
                    );

                    Navigator.pop(dialogContext);
                    
                    // Обновляем данные после закрытия диалога
                    if (mounted) {
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Учитель назначен'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    // Если диалог еще открыт, показываем ошибку в нем
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Назначить'),
              ),
            ],
          );
        },
      );
    },
  );
 }

  Future<void> _removeTeacherDialog(String assignmentId, String teacherName, String subjectName) async {
  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Удалить назначение'),
        content: Text('Вы уверены, что хотите удалить учителя $teacherName с предмета "$subjectName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );

  if (confirm == true) {
    try {
      await _subjectsService.removeTeacherFromSubject(assignmentId);
      
      if (mounted) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Назначение удалено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

  Widget _buildSubjectsTab() {
    return Column(
      children: [
        // Заголовок
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple[50],
          child: Row(
            children: [
              const Icon(Icons.subject, color: Colors.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Предметы школы',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.schoolName,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addSubjectDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить предмет'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                ),
              ),
            ],
          ),
        ),

        // Список предметов
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _subjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.subject, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Нет предметов', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('Добавьте первый предмет', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _addSubjectDialog,
                            child: const Text('Добавить предмет'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        final subjectId = subject['subjectId'];
                        final teachers = _teachersBySubject[subjectId] ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple,
                              child: Text(
                                subject['name'].toString().substring(0, 1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(subject['name']),
                            subtitle: Text(
                              teachers.isEmpty 
                                ? 'Нет назначенных учителей' 
                                : 'Учителей: ${teachers.length}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_add, size: 20),
                              onPressed: () => _assignTeacherDialog(subjectId, subject['name']),
                              tooltip: 'Назначить учителя',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    // Список учителей
                                    if (teachers.isEmpty)
                                      const Text(
                                        'Нет назначенных учителей',
                                        style: TextStyle(color: Colors.grey),
                                      )
                                    else
                                      ...teachers.map((teacher) {
                                        return ListTile(
                                          leading: const Icon(Icons.person, size: 20),
                                          title: Text(teacher['teacherName']),
                                          subtitle: Text(
                                            'Назначен: ${_formatDate(teacher['assignedAt'])}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _removeTeacherDialog(
                                              teacher['assignmentId'],
                                              teacher['teacherName'],
                                              subject['name'],
                                            ),
                                            tooltip: 'Удалить назначение',
                                          ),
                                        );
                                      }).toList(),
                                    
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _assignTeacherDialog(subjectId, subject['name']),
                                        icon: const Icon(Icons.person_add, size: 16),
                                        label: const Text('Добавить учителя'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple[50],
                                          foregroundColor: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsTab() {
    return Column(
      children: [
        // Заголовок
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple[50],
          child: const Row(
            children: [
              Icon(Icons.person, color: Colors.purple),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Все назначения',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Учителя и их предметы',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Список учителей с предметами
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allTeachers.isEmpty
                  ? const Center(child: Text('Нет учителей в школе'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _allTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _allTeachers[index];
                        
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _subjectsService.getTeacherSubjects(teacher['teacherId']),
                          builder: (context, snapshot) {
                            final subjects = snapshot.data ?? [];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Text(
                                    teacher['fullName'].toString().substring(0, 1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(teacher['fullName']),
                                subtitle: Text(teacher['email']),
                                trailing: Chip(
                                  label: Text('${subjects.length} предметов'),
                                  backgroundColor: Colors.purple[50],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        if (subjects.isEmpty)
                                          const Text(
                                            'Нет назначенных предметов',
                                            style: TextStyle(color: Colors.grey),
                                          )
                                        else
                                          ...subjects.map((subject) {
                                            return ListTile(
                                              leading: const Icon(Icons.subject, size: 20, color: Colors.purple),
                                              title: Text(subject['subjectName']),
                                              subtitle: Text(
                                                'Назначен: ${_formatDate(subject['assignedAt'])}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            );
                                          }).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление предметами'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.subject), text: 'Предметы'),
            Tab(icon: Icon(Icons.person), text: 'Назначения'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubjectsTab(),
          _buildAssignmentsTab(),
        ],
      ),
    );
  }
}