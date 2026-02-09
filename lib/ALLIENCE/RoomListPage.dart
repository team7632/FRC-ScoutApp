import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
// 確保導入了 StartScout 頁面
import 'package:flutter_application_1/ALLIENCE/startscout.dart';

import 'api.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {

  // 從伺服器獲取房間列表的非同步方法
  Future<List<dynamic>> _fetchRooms() async {
    final String serverIp = Api.serverIp;

    final url = Uri.parse('http://$serverIp:3000/v1/rooms');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // 成功取得資料
        return jsonDecode(response.body);
      } else {
        throw Exception('伺服器回應錯誤: ${response.statusCode}');
      }
    } catch (e) {
      // 捕捉網路連線失敗或逾時
      throw Exception('無法連線至伺服器: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("伺服器房間列表"),
      ),
      child: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _fetchRooms(),
          builder: (context, snapshot) {
            // 1. 載入中狀態
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            // 2. 發生錯誤狀態
            else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Error: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                ),
              );
            }

            // 3. 資料為空狀態
            else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("目前沒有任何房間"));
            }

            // 4. 成功取得資料後的渲染
            final rooms = snapshot.data!;

            return ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text("AVAILABLE ROOMS"),
                  footer: Text("找到 ${rooms.length} 個房間"),
                  children: rooms.map((room) {
                    // 從後端回傳的 JSON 中提取資料
                    final String roomName = room['name'] ?? "未知房間";
                    final String ownerName = room['owner'] ?? "匿名系統";

                    return CupertinoListTile(
                      title: Text(roomName),
                      // 這裡顯示房間持有人
                      subtitle: Text("持有人: $ownerName"),
                      leading: const Icon(
                          CupertinoIcons.house_fill,
                          color: CupertinoColors.activeBlue
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () {
                        // 點擊後跳轉至掃描或偵察頁面
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => StartScout(roomName: roomName),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}