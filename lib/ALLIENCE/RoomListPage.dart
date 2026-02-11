import 'dart:convert';
import 'package:flutter/material.dart'; // 切換至 Material
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/ALLIENCE/startscout.dart';
import 'api.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  // 使用更現代的紫色調
  final Color _brandPurple = const Color(0xFF673AB7);

  Future<List<dynamic>> _fetchRooms() async {
    final String serverIp = Api.serverIp;
    final url = Uri.parse('$serverIp/v1/rooms');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('伺服器代碼: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('無法連線至伺服器，請檢查網路設定');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // 背景改為極淡的藍紫色調
      appBar: AppBar(
        title: const Text(
          "伺服器房間列表",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500), // 移除粗體
        ),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 1, // 滾動時產生的微小陰影
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: _brandPurple,
        child: FutureBuilder<List<dynamic>>(
          future: _fetchRooms(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 3));
            }

            if (snapshot.hasError) {
              return _buildErrorView(snapshot.error.toString());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyView();
            }

            final rooms = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: rooms.length,
              itemBuilder: (context, index) => _buildRoomCard(rooms[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoomCard(dynamic room) {
    final String roomName = room['name'] ?? "未知房間";
    final String ownerName = room['owner'] ?? "匿名";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // 加上細微的邊框，讓卡片在淡色背景中跳出來
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StartScout(roomName: roomName)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                // 房間圖標容器
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _brandPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.meeting_room_outlined, color: _brandPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 文字內容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500, // 改用中圓體
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            "擁有者: $ownerName",
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w300),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w300),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text("再試一次"),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "目前沒有任何房間",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }
}