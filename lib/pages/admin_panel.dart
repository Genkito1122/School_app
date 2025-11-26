import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_app/services/code_service.dart';
import 'package:clipboard/clipboard.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final CodeService _codeService = CodeService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Заголовок
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Панель администратора',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<Map<String, dynamic>>(
                  future: _codeService.getAdminStats(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final stats = snapshot.data!;
                      return Text(
                        'Школ: ${stats['schoolsCount']} | Заявок: ${stats['pendingRequests']}/${stats['totalRequests']} | Кодов: ${stats['activeAdminCodes']}',
                        style: const TextStyle(color: Colors.white70),
                      );
                    }
                    return const Text(
                      'Загрузка статистики...',
                      style: TextStyle(color: Colors.white70),
                    );
                  },
                ),
              ],
            ),
          ),

          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTab(0, 'Заявки', Icons.list_alt),
                _buildTab(1, 'Школы', Icons.school),
                _buildTab(2, 'Коды', Icons.vpn_key),
                _buildTab(3, 'Статистика', Icons.analytics),
              ],
            ),
          ),
          Expanded(
            child: _buildCurrentTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: Material(
        color: isSelected ? Colors.white : Colors.grey[100],
        child: InkWell(
          onTap: () => setState(() => _currentTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isSelected ? Colors.teal : Colors.grey),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.teal : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 0:
        return _buildRequestsTab();
      case 1:
        return _buildSchoolsTab();
      case 2:
        return _buildCodesTab();
      case 3:
        return _buildStatsTab();
      default:
        return const Center(child: Text('Раздел в разработке'));
    }
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _codeService.getAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нет заявок', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final status = data['status'];
            
            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildStatusBadge(status),
                        const Spacer(),
                        Text(
                          _formatDate(data['createdAt']),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Новая школа: ${data['schoolName']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Директор: ${data['applicantName']}'),
                    Text('Email: ${data['applicantEmail']}'),
                    Text('Телефон: ${data['applicantPhone']}'),
                    Text('Адрес: ${data['schoolAddress']}'),
                    Text('AdminCode: ${data['adminCode']}'),
                    
                    if (status == 'pending') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approveRequest(request.id, data),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Одобрить', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _rejectRequest(request.id),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (status == 'approved') ...[
                      const SizedBox(height: 8),
                      Text(
                        '✅ Одобрено ${_formatDate(data['processedAt'])}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      if (data['schoolCode'] != null)
                        Text('Код школы: ${data['schoolCode']}'),
                    ] else if (status == 'rejected') ...[
                      const SizedBox(height: 8),
                      Text(
                        '❌ Отклонено ${_formatDate(data['processedAt'])}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      if (data['rejectionReason'] != null)
                        Text('Причина: ${data['rejectionReason']}'),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSchoolsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('schools').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нет школ', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        final schools = snapshot.data!.docs;

        return ListView.builder(
          itemCount: schools.length,
          itemBuilder: (context, index) {
            final school = schools[index];
            final data = school.data() as Map<String, dynamic>;
            final teacherCodes = List<String>.from(data['teacherCodes'] ?? []);
            
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.school, color: Colors.blue),
                title: Text(data['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['address']),
                    Text('Код школы: ${data['schoolCode']}'),
                    Text('Активных кодов учителей: ${teacherCodes.length}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCodesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Генерация кодов для директоров',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Сгенерируйте код и передайте его будущему директору школы. Код действителен 30 дней.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateAdminCode,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Сгенерировать новый код'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Активные коды:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildAdminCodesList(),
          ),
        ],
      ),
    );
  }

   Widget _buildAdminCodesList() {
   return FutureBuilder<List<Map<String, dynamic>>>(
     future: _getAdminCodes(),
     builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(child: Text('Ошибка: ${snapshot.error}'));
      }

      final codes = snapshot.data ?? [];

      if (codes.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Нет активных кодов', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text(
                'Сгенерируйте новый код для директора',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: codes.length,
        itemBuilder: (context, index) {
          final codeData = codes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.vpn_key, color: Colors.green),
              title: Text(
                codeData['code'],
                style: const TextStyle(fontFamily: 'Monospace', fontSize: 16),
              ),
              subtitle: Text(
                'Действует до: ${_formatDate(codeData['expiresAt'])}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.content_copy, size: 20),
                onPressed: () => _copyToClipboard(codeData['code']),
               ),
             ),
           );
         },
       );
     },
   );
 }

  Widget _buildStatsTab() {
  return FutureBuilder<Map<String, dynamic>>(
    future: _codeService.getAdminStats(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Ошибка загрузки статистики', 
                  style: TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              Text('${snapshot.error}', 
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Повторить'),
              ),
            ],
          ),
        );
      }

      if (!snapshot.hasData) {
        return const Center(child: Text('Нет данных статистики'));
      }

      final stats = snapshot.data!;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatCard('Школ', stats['schoolsCount'].toString(), Icons.school, Colors.blue),
            const SizedBox(height: 12),
            _buildStatCard('Заявок ожидает', stats['pendingRequests'].toString(), Icons.pending_actions, Colors.orange),
            const SizedBox(height: 12),
            _buildStatCard('Всего заявок', stats['totalRequests'].toString(), Icons.list_alt, Colors.green),
            const SizedBox(height: 12),
            _buildStatCard('Активных кодов', stats['activeAdminCodes'].toString(), Icons.vpn_key, Colors.purple),
            const SizedBox(height: 12),
            _buildStatCard('Всего пользователей', stats['totalUsers'].toString(), Icons.people, Colors.teal),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Пользователи по ролям:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRoleStat('Администраторы', stats['usersByRole']['admin'] ?? 0, Colors.purple),
                    _buildRoleStat('Директоры', stats['usersByRole']['director'] ?? 0, Colors.red),
                    _buildRoleStat('Учителя', stats['usersByRole']['teacher'] ?? 0, Colors.green),
                    _buildRoleStat('Ученики', stats['usersByRole']['student'] ?? 0, Colors.blue),
                    _buildRoleStat('Родители', stats['usersByRole']['parent'] ?? 0, Colors.orange),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
 }

 
 Widget _buildRoleStat(String role, int count, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(role)),
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
 }

 
 Widget _buildStatCard(String title, String value, IconData icon, Color color) {
   return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
 }

  Widget _buildStatusBadge(String status) {
    final color = status == 'pending' ? Colors.orange 
                : status == 'approved' ? Colors.green 
                : Colors.red;
                
    final text = status == 'pending' ? 'Ожидает' 
               : status == 'approved' ? 'Одобрено' 
               : 'Отклонено';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approveRequest(String requestId, Map<String, dynamic> data) async {
    try {
      final result = await _codeService.approveDirectorRequest(
        requestId: requestId,
        adminId: _currentUser!.uid,
        adminName: 'Администратор',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Школа "${result['schoolName']}" создана! Код: ${result['schoolCode']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить заявку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Укажите причину отклонения:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Причина отклонения...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите причину отклонения'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await _codeService.rejectDirectorRequest(
                  requestId: requestId,
                  adminId: _currentUser!.uid,
                  adminName: 'Администратор',
                  reason: reasonController.text.trim(),
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заявка отклонена'), backgroundColor: Colors.orange),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Отклонить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAdminCode() async {
  try {
    final newCode = await _codeService.generateAdminCode(
      createdByAdminId: _currentUser!.uid // ← Передаем ID админа
    );
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Новый код создан: $newCode'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ошибка создания кода: $e'),
        backgroundColor: Colors.red,
       ),
     );
   }
}

   Future<void> _copyToClipboard(String text) async {
   try {
     await FlutterClipboard.copy(text);
    
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
        content: Text('Код "$text" скопирован в буфер обмена'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
       ),
     );
    
     print('✅ Код скопирован: $text');
   }  catch (e) {
     print('❌ Ошибка копирования: $e');
    
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Ошибка копирования: $e'),
         backgroundColor: Colors.red,
         duration: const Duration(seconds: 3),
       ),
     );
   }
 }

  Future<List<Map<String, dynamic>>> _getAdminCodes() async {
  try {
    final snapshot = await _firestore
        .collection('admin_codes')
        .where('used', isEqualTo: false)
        .get();

     final now = DateTime.now();
     return snapshot.docs
        .map((doc) => doc.data())
        .where((data) {
          final expiresAt = data['expiresAt'] as Timestamp?;
          return expiresAt != null && expiresAt.toDate().isAfter(now);
        })
        .map((data) => {
          'code': data['code'],
          'expiresAt': data['expiresAt'],
        })
        .toList();
   } catch (e) {
    print('Ошибка загрузки кодов: $e');
    return [];
   }
 }
}