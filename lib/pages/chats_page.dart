import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/pages/chat_detail_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final ChatService _chatService = ChatService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Пользователь не авторизован')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getUserChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('У тебя пока нет активных чатов', 
              style: TextStyle(color: Colors.grey))
            );
          }

          final chats = _sortChatsByTime(snapshot.data!.docs);

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              return _buildChatItem(chatData);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chatData) {
    final chatId = chatData['chatId'];
    final chatType = chatData['type'];
    final lastMessage = chatData['lastMessage'] ?? 'Нет сообщений';
    final lastMessageTime = _formatTime(chatData['lastMessageTime']);
    final chatName = _chatService.getChatDisplayName(chatData, _currentUser!.uid);
    final chatIcon = _chatService.getChatIcon(chatType);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: _getChatColor(chatType).withOpacity(0.1),
        child: Icon(chatIcon, color: _getChatColor(chatType), size: 28),
      ),
      title: Text(
        chatName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      trailing: Text(
        lastMessageTime,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatId,
              chatName: chatName,
              chatType: chatType,
            ),
          ),
        );
      },
    );
  }

  Color _getChatColor(String chatType) {
    switch (chatType) {
      case 'class': return Colors.blue;
      case 'teachers': return Colors.green;
      case 'personal': return Colors.orange;
      case 'announcement': return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}.${date.month}';
  }

  List<QueryDocumentSnapshot> _sortChatsByTime(List<QueryDocumentSnapshot> chats) {
    List<QueryDocumentSnapshot> sorted = List.from(chats);
    sorted.sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }
}