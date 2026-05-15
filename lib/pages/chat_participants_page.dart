import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/chat_service.dart';
import 'package:school_app/pages/chat_detail_page.dart';

class ChatParticipantsPage extends StatelessWidget {
  final String chatId; 

  const ChatParticipantsPage({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Участники чата'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(

        stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
        builder: (context, chatSnapshot) {
          if (!chatSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          var chatData = chatSnapshot.data!.data() as Map<String, dynamic>?;
          if (chatData == null) return const Center(child: Text('Чат не найден'));


          List<dynamic> participantIds = chatData['participants'] ?? [];

          if (participantIds.isEmpty) {
            return const Center(child: Text('В чате нет участников'));
          }


          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _getUsersData(participantIds),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = usersSnapshot.data ?? [];

              final otherUsers = users.where((u) => u['uid'] != currentUserId).toList();

              if (otherUsers.isEmpty) {
                return const Center(child: Text('Вы единственный участник'));
              }

              return ListView.builder(
                itemCount: otherUsers.length,
                itemBuilder: (context, index) {
                  var user = otherUsers[index];
                  String name = user['fullName'] ?? user['name'] ?? 'Без имени';
                  String role = user['role'] ?? 'user';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRoleColor(role),
                        child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(name),
                      subtitle: Text(_translateRole(role)),
                      trailing: const Icon(Icons.send_outlined, color: Colors.blue, size: 20),
                      onTap: () => _goToPrivateChat(context, user['uid'], name),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }


  Future<List<Map<String, dynamic>>> _getUsersData(List<dynamic> uids) async {
    List<Map<String, dynamic>> foundUsers = [];

    List<String> collections = ['students', 'teachers', 'parents', 'principals'];

    for (var uid in uids) {
      bool found = false;
      for (var col in collections) {
        var doc = await FirebaseFirestore.instance.collection(col).doc(uid).get();
        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          data['uid'] = doc.id;
          data['role'] = col; 
          foundUsers.add(data);
          found = true;
          break; 
        }
      }

      if (!found) {
        var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
           var data = doc.data() as Map<String, dynamic>;
           data['uid'] = doc.id;
           data['role'] = data['role'] ?? 'user';
           foundUsers.add(data);
        }
      }
    }
    return foundUsers;
  }

  Color _getRoleColor(String role) {
    if (role.contains('teacher')) return Colors.orange;
    if (role.contains('student')) return Colors.blue;
    if (role.contains('parent')) return Colors.green;
    return Colors.grey;
  }

  String _translateRole(String role) {
    if (role.contains('teacher')) return 'Учитель';
    if (role.contains('student')) return 'Ученик';
    if (role.contains('parent')) return 'Родитель';
    if (role.contains('principal')) return 'Директор';
    return 'Участник';
  }

  void _goToPrivateChat(BuildContext context, String targetUid, String targetName) async {
  try {
    final chatService = ChatService();
    
    final chatId = await chatService.createOrGetPersonalChat(
      otherUserId: targetUid,
      otherUserName: targetName,
    );
    
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatId,
            chatName: targetName,
            chatType: 'personal',
          ),
        ),
      );
    }
  } catch (e) {
    print('❌ Ошибка: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка: $e')),
    );
  }
}
}