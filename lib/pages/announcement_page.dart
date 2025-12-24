import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _textController = TextEditingController();
  
  List<String> _selectedTargets = ['teachers'];
  bool _isSending = false;
  late TabController _tabController;

  final List<Map<String, dynamic>> _targetOptions = [
    {'value': 'teachers', 'label': 'Учителям', 'icon': Icons.school},
    {'value': 'class', 'label': 'Во все классы', 'icon': Icons.group},
    {'value': 'all', 'label': 'Всем абсолютно', 'icon': Icons.all_inclusive},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
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
                              } else {
                                _selectedTargets.remove('all');
                                _selectedTargets.add(option['value']);
                              }
                            } else {
                              _selectedTargets.remove(option['value']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

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
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  : const Icon(Icons.send),
              label: Text(_isSending ? 'Отправка...' : 'Отправить объявление'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
        print('❌ Ошибка загрузки истории: ${snapshot.error}');
        return Center(
          child: Text('Ошибка загрузки: ${snapshot.error}'),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        print('ℹ️ Нет объявлений в истории');
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
      print('✅ Загружено объявлений: ${announcements.length}');

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final announcement = announcements[index];
          final data = announcement.data() as Map<String, dynamic>;
          print('📝 Объявление $index: ${data['text']}');
          
          return _buildAnnouncementItem(data);
        },
      );
    },
  );
}

  Widget _buildAnnouncementItem(Map<String, dynamic> data) {
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
                Text(
                  _formatTime(data['createdAt']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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

    setState(() => _isSending = true);

    try {
      final userInfo = await _chatService.getUserInfoForMessage();
      
      await _chatService.sendAnnouncement(
        schoolId: widget.schoolId,
        text: text,
        senderName: userInfo['name']!,
        senderRole: userInfo['role']!,
        targetChatTypes: _selectedTargets,
      );

      _textController.clear();
      
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