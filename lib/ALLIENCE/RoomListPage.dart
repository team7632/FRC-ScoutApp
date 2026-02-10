import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/ALLIENCE/startscout.dart';
import 'api.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final Color _brandPurple = Colors.purple;

  Future<List<dynamic>> _fetchRooms() async {
    final String serverIp = Api.serverIp;
    final url = Uri.parse('$serverIp/v1/rooms');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('無法連線至伺服器');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        middle: const Text("伺服器房間列表", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      child: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _fetchRooms(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CupertinoActivityIndicator(color: _brandPurple));
            }

            if (snapshot.hasError) {
              return _buildErrorView(snapshot.error.toString());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyView();
            }

            final rooms = snapshot.data!;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async => setState(() {}),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRoomCard(rooms[index]),
                      childCount: rooms.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoomCard(dynamic room) {
    final String roomName = room['name'] ?? "未知房間";
    final String ownerName = room['owner'] ?? "匿名";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => StartScout(roomName: roomName)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // --- 這裡更換為你的 assets 圖標 ---
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8), // 縮減內邊距讓圖標大小適中
              decoration: BoxDecoration(
                color: _brandPurple.withOpacity(0.05), // 極淡紫色背景
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/images/icon.png',
                fit: BoxFit.contain, // 確保圖標比例正確
                // 如果你的 icon 是透明底純色，可以視情況加上 color: _brandPurple,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roomName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                  const SizedBox(height: 4),
                  Text("OWNER: $ownerName",
                      style: const TextStyle(fontSize: 13, color: Colors.grey)
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey4),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.wifi_exclamationmark, size: 50, color: Colors.redAccent),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(child: Text("目前沒有任何房間", style: TextStyle(color: Colors.grey)));
  }
}