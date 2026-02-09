import 'package:flutter/cupertino.dart';
import 'package:flutter_application_1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart'; // 必須引入
import 'CreateRoomPage.dart';
import 'RoomListPage.dart';


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _currentUserName = "載入中...";
  String? _photoUrl;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();


    GoogleSignInAccount? currentUser = _googleSignIn.currentUser;
    currentUser ??= await _googleSignIn.signInSilently();

    setState(() {

      _currentUserName = prefs.getString('username') ?? currentUser?.displayName ?? "Scout";

      // 獲取頭像網址
      _photoUrl = currentUser?.photoUrl;
    });

    print("當前使用者頭像: $_photoUrl");
  }


  void _showAccountMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(_currentUserName),
        message: const Text("帳戶管理"),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context); // 關閉選單
              _handleLogout(); // 執行登出
            },
            child: const Text("登出帳戶"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("取消"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("登出"),
        content: const Text("確定要登出並清除所有登入資訊嗎？"),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("確定"),
            onPressed: () async {
              try {
                // 1. 同時登出 Google 並清除本地快取
                await _googleSignIn.signOut();
                await prefs.clear();

                if (mounted) {
                  // 2. 正確跳轉：直接跳回你的登入頁面（RegisterPage 或 People）
                  // 不要跳轉到 MyApp，那是整個 App 的入口點
                  Navigator.of(context).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (context) => const RegisterPage()),
                        (route) => false,
                  );
                }
              } catch (e) {
                print("Logout error: $e");
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground, // 修正底色
      navigationBar: CupertinoNavigationBar(
        middle: const Text('7632SCOUT'),
        trailing: GestureDetector(
          onTap: _showAccountMenu, // 點擊頭像彈出選單
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: ClipOval(
              child: _photoUrl != null
                  ? Image.network(
                _photoUrl!,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                // 圖片加載錯誤時的備案
                errorBuilder: (context, error, stackTrace) =>
                const Icon(CupertinoIcons.person_crop_circle_fill),
              )
                  : const Icon(CupertinoIcons.person_crop_circle_fill, size: 30),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 這裡也放一個大頭像增加設計感
                if (_photoUrl != null)
                  ClipOval(
                    child: Image.network(_photoUrl!, width: 80, height: 80),
                  )
                else
                  const Icon(CupertinoIcons.person_crop_circle_fill, size: 80, color: CupertinoColors.systemGrey),

                const SizedBox(height: 20),
                Text(
                  "Hi, $_currentUserName",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "歡迎回來！",
                  style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 16),
                ),
                const SizedBox(height: 50),

                // 建立房間按鈕
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    color: CupertinoColors.systemPurple,
                    onPressed: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const CreateRoomPage()),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add),
                        SizedBox(width: 8),
                        Text('Create Room via API'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // 查看房間清單按鈕
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: CupertinoColors.systemPurple.withOpacity(0.1),
                    onPressed: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const RoomListPage()),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.list_bullet, color: CupertinoColors.systemPurple),
                        SizedBox(width: 8),
                        Text(
                          'View Rooms from Server',
                          style: TextStyle(color: CupertinoColors.systemPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

