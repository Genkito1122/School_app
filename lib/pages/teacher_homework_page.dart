import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/homework_service.dart';
import 'package:school_app/services/subjects_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherHomeworkPage extends StatefulWidget {
  const TeacherHomeworkPage({super.key});

  @override
  State<TeacherHomeworkPage> createState() => _TeacherHomeworkPageState();
}

class _TeacherHomeworkPageState extends State<TeacherHomeworkPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubjectsService _subjectsService = SubjectsService();
  
  List<Map<String, dynamic>> _homeworks = [];
  List<Map<String, dynamic>> _classes = []; // Классы учителя
  List<Map<String, dynamic>> _assignedSubjects = []; // Назначенные предметы учителя
  
  bool _isLoading = true;
  bool _isCreating = false;
  int _currentTab = 0;

  // Контроллеры для создания ДЗ
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  
  // Выбранные значения
  String? _selectedClassId;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);
      
      print('🔄 Загрузка данных учителя: ${user.uid}');
      
      // 1. Загружаем классы учителя
      await _loadTeacherClasses(user.uid);
      
      // 2. Загружаем назначенные предметы учителя
      await _loadAssignedSubjects(user.uid);
      
      // 3. Загружаем ДЗ учителя
      await _loadHomeworks(user.uid);
      
    } catch (e) {
      print('❌ Ошибка загрузки данных: $e');
      _showError('Ошибка загрузки: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeacherClasses(String teacherId) async {
    try {
      final teacherDoc = await _firestore.collection('teachers').doc(teacherId).get();
      
      if (!teacherDoc.exists) {
        print('❌ Документ учителя не найден');
        return;
      }
      
      final classIds = List<String>.from(teacherDoc.data()?['classIds'] ?? []);
      print('📚 ID классов учителя: $classIds');
      
      if (classIds.isEmpty) {
        print('⚠️ У учителя нет классов');
        return;
      }
      
      final classesSnapshot = await _firestore
          .collection('classes')
          .where('classId', whereIn: classIds)
          .get();
      
      setState(() {
        _classes = classesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'classId': doc.id,
            'name': data['name'] ?? 'Без названия',
            'schoolId': data['schoolId'],
          };
        }).toList();
        
        print('✅ Загружено классов: ${_classes.length}');
        
        // Выбираем первый класс по умолчанию
        if (_classes.isNotEmpty) {
          _selectedClassId = _classes.first['classId'];
          print('🎯 Выбран класс: $_selectedClassId');
        }
      });
      
    } catch (e) {
      print('❌ Ошибка загрузки классов: $e');
      rethrow;
    }
  }

  Future<void> _loadAssignedSubjects(String teacherId) async {
    try {
      print('🔄 Загрузка назначенных предметов...');
      
      // Используем SubjectsService для получения предметов учителя
      final subjects = await _subjectsService.getTeacherSubjects(teacherId);
      
      print('✅ Назначенных предметов: ${subjects.length}');
      for (final subject in subjects) {
        print('📖 ${subject['subjectName']} (${subject['subjectId']})');
      }
      
      setState(() {
        _assignedSubjects = subjects;
        
        // Выбираем первый предмет по умолчанию, если есть
        if (_assignedSubjects.isNotEmpty && _selectedSubjectId == null) {
          _selectedSubjectId = _assignedSubjects.first['subjectId'];
        }
      });
      
    } catch (e) {
      print('❌ Ошибка загрузки назначенных предметов: $e');
      rethrow;
    }
  }

  Future<void> _loadHomeworks(String teacherId) async {
  try {
    print('🔄 Загрузка ДЗ для учителя: $teacherId');
    
    final snapshot = await _firestore
        .collection('homeworks')
        .where('teacherId', isEqualTo: teacherId)
        .where('isActive', isEqualTo: true)
        .orderBy('deadline')
        .get();
    
    print('📄 Найдено документов ДЗ: ${snapshot.docs.length}');
    
    if (snapshot.docs.isNotEmpty) {
      for (final doc in snapshot.docs) {
        print('📝 ДЗ ID: ${doc.id}, данные: ${doc.data()}');
      }
    }
    
    setState(() {
      _homeworks = snapshot.docs.map((doc) {
        final data = doc.data();
        final deadline = data['deadline'] as Timestamp?;
        final now = DateTime.now();
        
        DateTime? deadlineDate;
        bool isOverdue = false;
        int daysLeft = 0;
        
        if (deadline != null) {
          deadlineDate = deadline.toDate();
          isOverdue = deadlineDate.isBefore(now);
          
          if (!isOverdue) {
            final difference = deadlineDate.difference(now);
            daysLeft = difference.inDays + 1;
          }
        }
        
        return {
          'homeworkId': doc.id,
          ...data,
          'deadline': deadline,
          'isOverdue': isOverdue,
          'daysLeft': daysLeft,
        };
      }).toList();
      
      print('✅ Загружено ДЗ: ${_homeworks.length}');
      
      // Сортируем по дате дедлайна
      _homeworks.sort((a, b) {
        final deadlineA = a['deadline'] as Timestamp?;
        final deadlineB = b['deadline'] as Timestamp?;
        
        if (deadlineA == null) return 1;
        if (deadlineB == null) return -1;
        
        return deadlineA.compareTo(deadlineB);
      });
    });
    
  } catch (e) {
    print('❌ Ошибка загрузки ДЗ: $e');
    _showError('Ошибка загрузки ДЗ: $e');
  }
 }

  Future<void> _createHomework() async {
    // ПРОВЕРКА ВСЕХ ПОЛЕЙ
    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      _showError('Выберите класс');
      return;
    }
    
    if (_selectedSubjectId == null || _selectedSubjectId!.isEmpty) {
      _showError('Выберите предмет');
      return;
    }
    
    if (_titleController.text.trim().isEmpty) {
      _showError('Введите название ДЗ');
      return;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Введите описание ДЗ');
      return;
    }
    
    if (_selectedDate == null) {
      _showError('Выберите дедлайн');
      return;
    }
    
    if (_selectedDate!.isBefore(DateTime.now())) {
      _showError('Дедлайн не может быть в прошлом');
      return;
    }
    
    // НАХОДИМ ВЫБРАННЫЕ ЗНАЧЕНИЯ
    final selectedClass = _classes.firstWhere(
      (c) => c['classId'] == _selectedClassId,
      orElse: () => {'name': 'Неизвестный класс'},
    );
    
    final selectedSubject = _assignedSubjects.firstWhere(
      (s) => s['subjectId'] == _selectedSubjectId,
      orElse: () => {'subjectName': 'Неизвестный предмет'},
    );
    
    // ПОЛУЧАЕМ ДАННЫЕ УЧИТЕЛЯ
    final user = _auth.currentUser;
    if (user == null) {
      _showError('Пользователь не авторизован');
      return;
    }
    
    final teacherDoc = await _firestore.collection('teachers').doc(user.uid).get();
    final teacherName = teacherDoc.data()?['fullName'] ?? 'Учитель';
    
    // БЛОКИРУЕМ КНОПКУ
    setState(() => _isCreating = true);
    
    try {
      print('🔄 Создание ДЗ...');
      print('📚 Класс: ${selectedClass['name']}');
      print('📖 Предмет: ${selectedSubject['subjectName']}');
      print('📅 Дедлайн: $_selectedDate');
      
      // СОЗДАЕМ ДЗ НАПРЯМУЮ В FIRESTORE
      final homeworkRef = _firestore.collection('homeworks').doc();
      
      await homeworkRef.set({
        'homeworkId': homeworkRef.id,
        'classId': _selectedClassId,
        'className': selectedClass['name'],
        'subjectId': _selectedSubjectId,
        'subjectName': selectedSubject['subjectName'],
        'teacherId': user.uid,
        'teacherName': teacherName,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'deadline': Timestamp.fromDate(_selectedDate!),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ ДЗ успешно создано: ${homeworkRef.id}');
      

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedDate = null;
      });
      
      _showSuccess('Домашнее задание создано!');
      
      // ПЕРЕКЛЮЧАЕМ НА ВКЛАДКУ С ДЗ
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _currentTab = 1);
      await _loadHomeworks(user.uid);
      
    } catch (e) {
      print('❌ Ошибка создания ДЗ: $e');
      _showError('Ошибка создания ДЗ: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteHomework(String homeworkId) async {
    try {
      await _firestore.collection('homeworks').doc(homeworkId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      
      final user = _auth.currentUser;
      if (user != null) {
        await _loadHomeworks(user.uid);
      }
      
      _showSuccess('ДЗ удалено');
    } catch (e) {
      _showError('Ошибка удаления: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Создание домашнего задания',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // ПРОВЕРКА: ЕСТЬ ЛИ КЛАССЫ У УЧИТЕЛЯ
          if (_classes.isEmpty)
            _buildNoClassesMessage()
          else
            Column(
              children: [
                // ВЫБОР КЛАССА
                _buildClassSelector(),
                const SizedBox(height: 16),
                
                // ВЫБОР ПРЕДМЕТА
                _buildSubjectSelector(),
                
                const SizedBox(height: 16),
                
                // НАЗВАНИЕ ДЗ
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название ДЗ',
                    hintText: 'Например: Упражнение 5-10, стр. 45',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // ОПИСАНИЕ ДЗ
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание задания',
                    hintText: 'Подробное описание...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 4,
                ),
                
                const SizedBox(height: 16),
                
                // ДАТА ДЕДЛАЙНА
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дедлайн',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedDate == null
                              ? 'Выберите дату'
                              : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}',
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // КНОПКА СОЗДАНИЯ
                _buildCreateButton(),
              ],
            ),
          
          const SizedBox(height: 20),
          
          // ПОДСКАЗКИ
          _buildTips(),
          
        ],
      ),
    );
  }

  Widget _buildNoClassesMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_off, size: 48, color: Colors.orange),
          SizedBox(height: 12),
          Text(
            'У вас нет классов',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Вас не назначили классным руководителем. '
            'Обратитесь к директору или завучу.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Класс:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _selectedClassId,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('Выберите класс'),
            items: _classes.map((classItem) {
              return DropdownMenuItem<String>(
                value: classItem['classId'],
                child: Text(classItem['name']),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _selectedClassId = newValue);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Предмет:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        if (_assignedSubjects.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: const Column(
              children: [
                Text(
                  'Вам не назначили предметы',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Обратитесь к завучу для назначения предметов',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
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
              value: _selectedSubjectId,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('Выберите предмет'),
              items: _assignedSubjects.map((subject) {
                return DropdownMenuItem<String>(
                  value: subject['subjectId'],
                  child: Text(subject['subjectName']),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => _selectedSubjectId = newValue);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCreateButton() {
    final isFormValid = _selectedClassId != null &&
        _selectedSubjectId != null &&
        _titleController.text.isNotEmpty &&
        _descriptionController.text.isNotEmpty &&
        _selectedDate != null;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isFormValid && !_isCreating) ? _createHomework : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isFormValid ? Colors.green : Colors.grey,
          disabledBackgroundColor: Colors.grey,
        ),
        child: _isCreating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('Создать ДЗ', style: TextStyle(fontSize: 16)),
                ],
              ),
      ),
    );
  }

  Widget _buildTips() {
    return Card(
      color: Colors.blue[50],
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💡 Подсказки:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Ученики увидят ДЗ сразу после создания'),
            Text('• Родители также будут видеть ДЗ своего ребенка'),
            Text('• Просроченные ДЗ автоматически деактивируются'),
            Text('• ДЗ можно удалить в любой момент'),
          ],
        ),
      ),
    );
  }

  Widget _buildMyHomeworksTab() {
    if (_homeworks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Нет домашних заданий', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Создайте первое ДЗ для ваших учеников', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        _buildStatistics(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final user = _auth.currentUser;
              if (user != null) {
                await _loadHomeworks(user.uid);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _homeworks.length,
              itemBuilder: (context, index) {
                final hw = _homeworks[index];
                return _buildHomeworkCard(hw);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    final active = _homeworks.where((hw) => !hw['isOverdue']).length;
    final overdue = _homeworks.where((hw) => hw['isOverdue']).length;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Активных', '$active', Colors.green),
            _buildStatItem('Просрочено', '$overdue', Colors.red),
            _buildStatItem('Всего', '${_homeworks.length}', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> homework) {
  print('🔄 Отрисовка карточки ДЗ: ${homework['homeworkId']}');
  
  final deadline = homework['deadline'] as Timestamp?;
  DateTime? deadlineDate;
  String deadlineText = 'Дата не указана';
  
  if (deadline != null) {
    deadlineDate = deadline.toDate();
    deadlineText = '${deadlineDate.day}.${deadlineDate.month}.${deadlineDate.year}';
  }
  
  final isOverdue = homework['isOverdue'] as bool? ?? false;
  final daysLeft = homework['daysLeft'] as int? ?? 0;
  
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: isOverdue ? Colors.red : Colors.green,
        child: Icon(
          isOverdue ? Icons.warning : Icons.assignment,
          color: Colors.white,
        ),
      ),
      title: Text(
        homework['title']?.toString() ?? 'Без названия',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${homework['subjectName']?.toString() ?? 'Предмет'} • '
            '${homework['className']?.toString() ?? 'Класс'}'
          ),
          Text(
            'До: $deadlineText',
            style: TextStyle(
              color: isOverdue ? Colors.red : Colors.grey,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (!isOverdue && daysLeft > 0)
            Text('Осталось дней: $daysLeft', style: const TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _showDeleteDialog(homework['homeworkId'], homework['title']),
        tooltip: 'Удалить',
      ),
      onTap: () => _showHomeworkDetails(homework),
    ),
  );
}

  Future<void> _showDeleteDialog(String homeworkId, String title) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить ДЗ?'),
        content: Text('Вы уверены, что хотите удалить "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteHomework(homeworkId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showHomeworkDetails(Map<String, dynamic> homework) async {
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
              Text('📚 ${homework['subjectName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('🏫 ${homework['className']}'),
              const SizedBox(height: 12),
              const Divider(),
              const Text('📝 Описание:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(homework['description']),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: isOverdue ? Colors.red : Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Дедлайн: ${deadline.day}.${deadline.month}.${deadline.year}',
                    style: TextStyle(color: isOverdue ? Colors.red : Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!isOverdue)
                Text('⏳ Осталось дней: $daysLeft', style: const TextStyle(color: Colors.green)),
              if (isOverdue)
                Text('⚠️ Просрочено', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('👨‍🏫 Создал: ${homework['teacherName']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.length > 100 ? '${message.substring(0, 100)}...' : message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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
          : DefaultTabController(
              length: 2,
              initialIndex: _currentTab,
              child: Column(
                children: [
                  Material(
                    color: Colors.white,
                    child: TabBar(
                      onTap: (index) => setState(() => _currentTab = index),
                      tabs: const [
                        Tab(icon: Icon(Icons.create), text: 'Создать'),
                        Tab(icon: Icon(Icons.list), text: 'Мои ДЗ'),
                      ],
                      indicatorColor: Colors.orange,
                      labelColor: Colors.orange,
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCreateTab(),
                        _buildMyHomeworksTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}