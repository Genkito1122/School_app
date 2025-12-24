import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/chat_service.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatType;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatType,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  bool _canWrite = false;
  Map<String, String> _userInfo = {'name': '', 'role': ''};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _checkWritePermission();
    await _loadUserInfo();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkWritePermission() async {
    final canWrite = await _chatService.canUserWriteToChat(widget.chatId);
    setState(() {
      _canWrite = canWrite;
    });
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await _chatService.getUserInfoForMessage();
    setState(() {
      _userInfo = userInfo;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        text: text,
        senderName: _userInfo['name']!,
        senderRole: _userInfo['role']!,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('❌ Ошибка отправки сообщения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'student': return Colors.blue;
      case 'teacher': return Colors.green;
      case 'parent': return Colors.orange;
      case 'director': return Colors.red;
      case 'admin': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            Text(
              _getChatSubtitle(widget.chatType),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: _getRoleColor(_userInfo['role']),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getChatMessages(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        print('❌ Ошибка StreamBuilder: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 64),
                              const SizedBox(height: 16),
                              Text('Ошибка загрузки: ${snapshot.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Нет сообщений'),
                              SizedBox(height: 8),
                              Text('Начните общение первым!', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      final messages = snapshot.data!.docs;
                      print('📨 Загружено сообщений: ${messages.length}');

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true, 
                        padding: const EdgeInsets.all(8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final messageData = message.data() as Map<String, dynamic>;
                          
                          print('📝 Сообщение $index: ${messageData['text']}');
                          
                          return _buildMessageItem(messageData);
                        },
                      );
                    },
                  ),
                ),

                if (_canWrite) _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> messageData) {
    final isMe = messageData['senderId'] == _currentUser?.uid;
    final messageType = messageData['type'] ?? 'text';
    final isAnnouncement = messageData['isAnnouncement'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getRoleColor(messageData['senderRole']),
              child: Text(
                messageData['senderName']?.toString().substring(0, 1) ?? '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: isAnnouncement 
                  ? Border.all(color: Colors.orange, width: 2)
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && !isAnnouncement)
                    Text(
                      messageData['senderName'] ?? 'Неизвестный',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  if (isAnnouncement)
                    Row(
                      children: [
                        Icon(Icons.campaign, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Объявление',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  
                  if (!isMe && !isAnnouncement) const SizedBox(height: 4),
                  
                  if (messageType == 'file')
                    _buildFileMessage(messageData)
                  else
                    Text(
                      messageData['text'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    _formatMessageTime(messageData['createdAt']),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _getRoleColor(_userInfo['role']),
              child: Text(
                _userInfo['name']?.substring(0, 1) ?? 'Я',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> messageData) {
    final fileName = messageData['fileName'] ?? 'Файл';
    final fileUrl = messageData['fileUrl'];

    return GestureDetector(
      onTap: () {
        if (fileUrl != null) {
          // Разработать: Открыть файл или скачать
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Файл: $fileName')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getFileIcon(fileName), size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getFileType(fileName),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (fileUrl != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.download, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.toLowerCase().contains('.pdf')) return Icons.picture_as_pdf;
    if (fileName.toLowerCase().contains('.doc')) return Icons.description;
    if (fileName.toLowerCase().contains('.xls')) return Icons.table_chart;
    if (fileName.toLowerCase().contains('.jpg') || 
        fileName.toLowerCase().contains('.png')) return Icons.image;
    return Icons.insert_drive_file;
  }

  String _getFileType(String fileName) {
    if (fileName.toLowerCase().contains('.pdf')) return 'PDF';
    if (fileName.toLowerCase().contains('.doc')) return 'Word';
    if (fileName.toLowerCase().contains('.xls')) return 'Excel';
    if (fileName.toLowerCase().contains('.jpg') || 
        fileName.toLowerCase().contains('.png')) return 'Изображение';
    return 'Файл';
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _canWrite ? 'Введите сообщение...' : 'Только чтение',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabled: _canWrite,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          
          IconButton(
            icon: Icon(Icons.send, color: _canWrite ? Colors.blue : Colors.grey),
            onPressed: _canWrite ? _sendMessage : null,
            tooltip: _canWrite ? 'Отправить' : 'Только чтение',
          ),
        ],
      ),
    );
  }

  String _getChatSubtitle(String chatType) {
    switch (chatType) {
      case 'class': return 'Классный чат';
      case 'teachers': return 'Чат учителей';
      case 'personal': return 'Личный чат';
      case 'announcement': return 'Объявления';
      default: return 'Чат';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}