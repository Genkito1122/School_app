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
    return Scaffold(
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
    return const Center(child: Text('Нет чатов'));
  }

  final chats = _sortChatsByTime(snapshot.data!.docs);

  return ListView.builder(
    itemCount: chats.length,
    itemBuilder: (context, index) {
      final chat = chats[index];
      final chatData = chat.data() as Map<String, dynamic>;
      
      return _buildChatItem(chatData);
    },
  );
}

      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chatData) {
    final chatId = chatData['chatId'];
    final chatType = chatData['type'];
    final lastMessage = chatData['lastMessage'] ?? '';
    final lastMessageTime = _formatTime(chatData['lastMessageTime']);
    final chatName = _chatService.getChatDisplayName(chatData, _currentUser!.uid);
    final chatIcon = _chatService.getChatIcon(chatType);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getChatColor(chatType),
          child: Icon(chatIcon, color: Colors.white),
        ),
        title: Text(
          chatName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              lastMessageTime,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
      ),
    );
  }

  Color _getChatColor(String chatType) {
    switch (chatType) {
      case 'class': return Colors.blue;
      case 'teachers': return Colors.green;
      case 'personal': return Colors.orange;
      case 'announcement': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}';
    }
  }

  List<QueryDocumentSnapshot> _sortChatsByTime(List<QueryDocumentSnapshot> chats) {
  chats.sort((a, b) {
    final aData = a.data() as Map<String, dynamic>;
    final bData = b.data() as Map<String, dynamic>;
    
    final aTime = aData['lastMessageTime'] as Timestamp?;
    final bTime = bData['lastMessageTime'] as Timestamp?;
    
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    
    return bTime.compareTo(aTime);
  });
  
  return chats;
 }
}