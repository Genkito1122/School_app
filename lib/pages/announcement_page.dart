import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_app/services/chat_service.dart';

class AnnouncementPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  const AnnouncementPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
  });

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _textController = TextEditingController();
  
  List<String> _selectedTargets = ['teachers'];
  String? _selectedClassId;
  bool _isSending = false;
  late TabController _tabController;

  List<Map<String, dynamic>> _classes = [];
  bool _isLoadingClasses = false;

  final List<Map<String, dynamic>> _targetOptions = [
    {'value': 'teachers', 'label': 'Учителям', 'icon': Icons.school},
    {'value': 'class', 'label': 'В класс', 'icon': Icons.group},
    {'value': 'all', 'label': 'Всем абсолютно', 'icon': Icons.all_inclusive},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);

    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() {
        _classes = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'classId': doc.id,
            'name': data['name'] ?? 'Без названия',
          };
        }).toList();
        
        // Сортируем по имени
        _classes.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      });
    } catch (e) {
      print('❌ Ошибка загрузки классов: $e');
    } finally {
      setState(() => _isLoadingClasses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Объявления - ${widget.schoolName}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.create), text: 'Создать'),
            Tab(icon: Icon(Icons.history), text: 'История'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Выбор получателей
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Кому отправить:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _targetOptions.map((option) {
                      final isSelected = _selectedTargets.contains(option['value']);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(option['label']),
                        avatar: Icon(option['icon'], size: 16),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (option['value'] == 'all') {
                                _selectedTargets = ['all'];
                                _selectedClassId = null;
                              } else {
                                _selectedTargets.remove('all');
                                _selectedTargets.add(option['value']);
                              }
                            } else {
                              _selectedTargets.remove(option['value']);
                              if (option['value'] == 'class') {
                                _selectedClassId = null;
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  // Выбор конкретного класса
                  if (_selectedTargets.contains('class')) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Выберите класс:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    if (_isLoadingClasses)
                      const Center(child: CircularProgressIndicator())
                    else if (_classes.isEmpty)
                      const Text('Нет классов в школе', style: TextStyle(color: Colors.grey))
                    else
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
                            setState(() => _selectedClassId = newValue);
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Текст объявления
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Введите текст объявления...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),

          const SizedBox(height: 16),

          // Кнопка отправки
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendAnnouncement,
              icon: _isSending 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSending ? 'Отправка...' : 'Отправить объявление'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getAnnouncementsHistory(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нет объявлений'),
                SizedBox(height: 8),
                Text('Создайте первое объявление', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final announcements = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            final data = announcement.data() as Map<String, dynamic>;
            return _buildAnnouncementItem(data);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementItem(Map<String, dynamic> data) {
    // Определяем иконку в зависимости от цели
    IconData targetIcon;
    String targetLabel;
    
    final targetType = data['targetType'] as String? ?? 'all';
    switch (targetType) {
      case 'teachers':
        targetIcon = Icons.school;
        targetLabel = 'Учителям';
        break;
      case 'class':
        targetIcon = Icons.group;
        targetLabel = 'Классу: ${data['targetName'] ?? ''}';
        break;
      case 'all':
        targetIcon = Icons.all_inclusive;
        targetLabel = 'Всем';
        break;
      default:
        targetIcon = Icons.campaign;
        targetLabel = 'Объявление';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Объявление',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(targetIcon, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      targetLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Text(
              _formatTime(data['createdAt']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              data['text'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'От: ${data['senderName']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAnnouncement() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст объявления')),
      );
      return;
    }

    if (_selectedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите получателей')),
      );
      return;
    }

    // Проверка: если выбран класс, но не выбран конкретный
    if (_selectedTargets.contains('class') && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите конкретный класс')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final userInfo = await _chatService.getUserInfoForMessage();
      
      // Если выбран конкретный класс — отправляем только туда
      if (_selectedTargets.contains('class') && _selectedClassId != null) {
        final selectedClass = _classes.firstWhere(
          (c) => c['classId'] == _selectedClassId,
          orElse: () => {'name': 'Класс'},
        );
        
        // Ищем чат класса
        final chatSnapshot = await _firestore
            .collection('chats')
            .where('classId', isEqualTo: _selectedClassId)
            .where('type', isEqualTo: 'class')
            .limit(1)
            .get();

        if (chatSnapshot.docs.isNotEmpty) {
          final chatId = chatSnapshot.docs.first.id;
          
          await _chatService.sendMessage(
            chatId: chatId,
            text: text,
            senderName: userInfo['name']!,
            senderRole: userInfo['role']!,
            isAnnouncement: true,
          );
        }

        // Сохраняем в историю
        await _firestore.collection('messages').add({
          'type': 'announcement',
          'schoolId': widget.schoolId,
          'text': text,
          'senderName': userInfo['name'],
          'senderRole': userInfo['role'],
          'isAnnouncement': true,
          'targetType': 'class',
          'targetId': _selectedClassId,
          'targetName': selectedClass['name'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Отправляем как обычно (учителям / всем)
        await _chatService.sendAnnouncement(
          schoolId: widget.schoolId,
          text: text,
          senderName: userInfo['name']!,
          senderRole: userInfo['role']!,
          targetChatTypes: _selectedTargets,
        );
      }

      _textController.clear();
      setState(() {
        _selectedTargets = ['teachers'];
        _selectedClassId = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Объявление отправлено!'),
          backgroundColor: Colors.green,
        ),
      );

      _tabController.animateTo(1);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}