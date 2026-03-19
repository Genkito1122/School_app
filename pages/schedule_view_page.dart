import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleViewPage extends StatefulWidget {
  const ScheduleViewPage({super.key});

  @override
  State<ScheduleViewPage> createState() => _ScheduleViewPageState();
}

class _ScheduleViewPageState extends State<ScheduleViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  Map<String, dynamic>? _scheduleData;
  bool _isLoading = true;
  String _selectedDay = 'monday';
  String? _classId;
  String? _className;
  String? _userRole;
  String _errorMessage = '';

  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      print('❌ Пользователь не авторизован');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Пользователь не авторизован';
      });
      return;
    }

    try {
      print('👤 Загрузка данных пользователя: ${_currentUser.uid}');
      
      final userDoc = await _firestore.collection('users').doc(_currentUser.uid).get();
      final userRole = userDoc.data()?['role'];
      print('🎭 Роль пользователя: $userRole');
      
      setState(() => _userRole = userRole);

      String? classId;
      String? className;

      switch (userRole) {
        case 'student':
          print('🎓 Загрузка данных ученика');
          final studentDoc = await _firestore.collection('students').doc(_currentUser.uid).get();
          if (studentDoc.exists) {
            classId = studentDoc.data()?['classId'];
            className = studentDoc.data()?['className'];
            print('📚 Ученик: классId=$classId, название=$className');
          } else {
            print('❌ Документ ученика не найден');
          }
          break;

        case 'parent':
          print('👪 Загрузка данных родителя');
          final parentDoc = await _firestore.collection('parents').doc(_currentUser.uid).get();
          if (parentDoc.exists) {
            final childIds = List<String>.from(parentDoc.data()?['childIds'] ?? []);
            print('👶 Дети родителя: $childIds');
            
            if (childIds.isNotEmpty) {
              final childDoc = await _firestore.collection('students').doc(childIds.first).get();
              if (childDoc.exists) {
                classId = childDoc.data()?['classId'];
                className = childDoc.data()?['className'];
                print('📚 Ребенок: классId=$classId, название=$className');
              }
            }
          }
          break;

        case 'teacher':
          print('👨‍🏫 Загрузка данных учителя');
          final teacherDoc = await _firestore.collection('teachers').doc(_currentUser.uid).get();
          if (teacherDoc.exists) {
            final classIds = List<String>.from(teacherDoc.data()?['classIds'] ?? []);
            print('📋 ID классов учителя: $classIds');
            
            if (classIds.isNotEmpty) {
              final classDoc = await _firestore.collection('classes').doc(classIds.first).get();
              if (classDoc.exists) {
                classId = classDoc.id;
                className = classDoc.data()?['name'];
                print('📚 Первый класс: ID=$classId, название=$className');
              }
            }
          }
          break;
          
        default:
          print('⚠️ Неизвестная роль: $userRole');
      }

      if (classId != null && className != null) {
      print('✅ Класс определен: $className (ID: $classId)');
      if (mounted) {
        setState(() {
          _classId = classId;
          _className = className;
          _errorMessage = '';
        });
      }
      await _loadSchedule();
    } else {
      print('⚠️ Не удалось определить класс');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Не удалось определить ваш класс';
        });
      }
    }
  } catch (e) {
    print('❌ Ошибка загрузки данных пользователя: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки: ${e.toString()}';
      });
    }
  }
 }

  Future<void> _loadSchedule() async {
  try {
    if (_classId == null) {
      print('❌ classId is null');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ID класса не определен';
        });
      }
      return;
    }
    
    print('🔄 Загрузка расписания для classId: $_classId');
    
    // Сначала ищем по прямому ID документа
    final scheduleDoc = await _firestore
        .collection('schedules')
        .doc(_classId!)
        .get();

    if (scheduleDoc.exists) {
      print('✅ Документ расписания найден по прямому ID');
      final data = scheduleDoc.data();
      
      if (mounted) {
        setState(() {
          _scheduleData = data;
          _errorMessage = '';
        });
      }
    } else {
      print('⚠️ Расписание не найдено по прямому ID');
      print('🔍 Ищем по полю classId в коллекции...');
      
      // Поиск по полю classId в коллекции
      final query = await _firestore
          .collection('schedules')
          .where('classId', isEqualTo: _classId)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        print('✅ Найден в query: ${query.docs.first.id}');
        final data = query.docs.first.data();
        
        if (mounted) {
          setState(() {
            _scheduleData = data;
            _errorMessage = '';
          });
        }
      } else {
        print('❌ Расписание не найдено вообще');
        if (mounted) {
          setState(() {
            _errorMessage = 'Расписание для класса "$_className" еще не создано';
          });
        }
      }
    }
  } catch (e) {
    print('❌ Ошибка загрузки расписания: $e');
    if (mounted) {
      setState(() {
        _errorMessage = 'Ошибка загрузки расписания: ${e.toString()}';
      });
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'student': return Colors.blue;
      case 'teacher': return Colors.green;
      case 'vice_principal': return Colors.purple;
      case 'parent': return Colors.orange;
      case 'director': return Colors.red;
      case 'admin': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _getDayDisplayName(String day) {
    switch (day) {
      case 'monday': return 'Понедельник';
      case 'tuesday': return 'Вторник';
      case 'wednesday': return 'Среда';
      case 'thursday': return 'Четверг';
      case 'friday': return 'Пятница';
      default: return day;
    }
  }

  List<Map<String, dynamic>> _getLessonsForDay(String day) {
    if (_scheduleData == null || _scheduleData!['days'] == null) {
      return [];
    }
    
    try {
      final days = _scheduleData!['days'] as List<dynamic>;
      for (var dayData in days) {
        if (dayData['day'] == day) {
          final lessons = dayData['lessons'] as List<dynamic>?;
          if (lessons == null) return [];
          
          return lessons.map((lesson) {
            if (lesson is Map<String, dynamic>) {
              return lesson;
            } else {
              return {'subject': '', 'room': '', 'time': '', 'teacher': ''};
            }
          }).toList();
        }
      }
    } catch (e) {
      print('❌ Ошибка получения уроков для дня $day: $e');
    }
    
    return [];
  }

  Widget _buildLessonView(Map<String, dynamic> lesson) {
    final subject = lesson['subject']?.toString() ?? '';
    final room = lesson['room']?.toString() ?? '';
    final time = lesson['time']?.toString() ?? '';
    final teacher = lesson['teacher']?.toString() ?? '';
    
    if (subject.isEmpty) {
      return const SizedBox.shrink();
    }

    // Получаем цвет роли
    final roleColor = _getRoleColor(_userRole);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Время
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Предмет
            Text(
              subject,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            
            const SizedBox(height: 4),
            
            if (teacher.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    teacher,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            
            // Кабинет
            if (room.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.room, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Каб. $room',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Отладочная информация
    print('=== ScheduleViewPage Build ===');
    print('isLoading: $_isLoading');
    print('classId: $_classId');
    print('className: $_className');
    print('userRole: $_userRole');
    print('scheduleData: ${_scheduleData != null ? "Есть" : "Нет"}');
    print('errorMessage: $_errorMessage');
    
    if (_scheduleData != null) {
      print('Ключи в scheduleData: ${_scheduleData!.keys.join(", ")}');
      if (_scheduleData!.containsKey('days')) {
        print('Дней в расписании: ${(_scheduleData!['days'] as List).length}');
      }
    }

    final roleColor = _getRoleColor(_userRole);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadUserData();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isLoading) return const Text('Загрузка...');
    
    if (_className != null) {
      return Text('Расписание - $_className');
    }
    
    return const Text('Расписание');
  }

  Widget _buildContent() {
    // Если есть ошибка
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.orange[700]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserData,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    
    // Если класс не определен
    if (_classId == null) {
      return _buildNoClassMessage();
    }
    
    // Если расписание не найдено
    if (_scheduleData == null) {
      return _buildNoScheduleMessage();
    }
    
    // Если нет структуры days
    if (!_scheduleData!.containsKey('days')) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Ошибка в структуре данных расписания',
            style: TextStyle(fontSize: 16, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            'Найденные поля: ${_scheduleData!.keys.join(", ")}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSchedule,
            child: const Text('Обновить данные'),
          ),
        ],
      );
    }
    
    // Нормальное отображение
    return _buildScheduleView();
  }

  Widget _buildScheduleView() {
    final roleColor = _getRoleColor(_userRole);
    final lessons = _getLessonsForDay(_selectedDay);
    final hasLessons = lessons.any((lesson) {
      final subject = lesson['subject']?.toString() ?? '';
      return subject.isNotEmpty;
    });

    return Column(
      children: [
        // Выбор дня недели
        Container(
          height: 70,
          color: Colors.grey[100],
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final day = _days[index];
              final isSelected = day == _selectedDay;
              final dayLessons = _getLessonsForDay(day);
              final dayHasLessons = dayLessons.any((lesson) {
                final subject = lesson['subject']?.toString() ?? '';
                return subject.isNotEmpty;
              });
              
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 65),
                  decoration: BoxDecoration(
                    color: isSelected ? roleColor : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: roleColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getDayDisplayName(day).substring(0, 3),
                        style: TextStyle(
                          color: isSelected ? Colors.white : roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (dayHasLessons)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      else
                        Text(
                          'День ${index + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : roleColor,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Информация о дне
        Container(
          padding: const EdgeInsets.all(8),
          color: roleColor.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 16, color: roleColor),
              const SizedBox(width: 8),
              Text(
                _getDayDisplayName(_selectedDay),
                style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (!hasLessons)
                Text(
                  '(Нет уроков)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
        ),

        // Расписание
        Expanded(
          child: _buildLessonsList(lessons, hasLessons),
        ),
      ],
    );
  }

  Widget _buildLessonsList(List<Map<String, dynamic>> lessons, bool hasLessons) {
    if (!hasLessons) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Нет уроков в ${_getDayDisplayName(_selectedDay).toLowerCase()}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    final filteredLessons = lessons.where((lesson) {
      final subject = lesson['subject']?.toString() ?? '';
      return subject.isNotEmpty;
    }).toList();
    
    if (filteredLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Нет уроков в ${_getDayDisplayName(_selectedDay).toLowerCase()}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredLessons.length,
      itemBuilder: (context, index) {
        final lesson = filteredLessons[index];
        return _buildLessonView(lesson);
      },
    );
  }

  Widget _buildNoClassMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Класс не назначен',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_userRole != null)
            Text(
              'Ваша роль: $_userRole',
              style: const TextStyle(color: Colors.grey),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            child: const Text('Повторить загрузку'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScheduleMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Расписание не заполнено',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_className != null)
            Text(
              'Класс: $_className',
              style: const TextStyle(color: Colors.grey),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSchedule,
            child: const Text('Загрузить расписание'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Вернуться назад'),
          ),
        ],
      ),
    );
  }
}