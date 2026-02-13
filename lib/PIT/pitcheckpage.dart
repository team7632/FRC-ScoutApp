import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../ALLIENCE/api.dart';
import 'path.dart';

class PitCheckPage extends StatefulWidget {
  final String teamNumber;
  final String roomName;

  const PitCheckPage({super.key, required this.teamNumber, required this.roomName});

  @override
  State<PitCheckPage> createState() => _PitCheckPageState();
}

class _PitCheckPageState extends State<PitCheckPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  File? _image;
  Uint8List? _serverImageBytes;
  final ImagePicker _picker = ImagePicker();

  // --- 配色方案 ---
  final Color bgDark = const Color(0xFF0A0E14);
  final Color cardDark = const Color(0xFF161B22);
  final Color primaryCyan = const Color(0xFF64FFDA);
  final Color accentBlue = const Color(0xFF3A7BD5);
  final Color textLight = const Color(0xFFE6F1FF);
  final Color textDim = const Color(0xFF8B949E);

  // --- 資料模型 ---
  String _description = "";
  String _selectedDrivetrain = "Swerve";
  int _maxBallCapacity = 0;
  String _shooterType = "shooter (Double)";
  bool _hasTurret = false;

  List<Map<String, dynamic>> _allPaths = [
    {"name": "Auto Path 1", "json": "[]"}
  ];

  bool _isInitialLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchExistingData();
  }

  /// 1. 抓取現有數據 (含 Ngrok 跳過警告 Header)
  Future<void> _fetchExistingData() async {
    try {
      final url = '${Api.serverIp}/v1/pit/get-data?roomName=${Uri.encodeComponent(widget.roomName)}&teamNumber=${widget.teamNumber}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "ngrok-skip-browser-warning": "69420", // ⭐ 關鍵：跳過 Ngrok 警告頁
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _description = data['description']?.toString() ?? "";
          _maxBallCapacity = int.tryParse(data['maxBallCapacity']?.toString() ?? "0") ?? 0;
          _shooterType = data['shooterType']?.toString() ?? "shooter (Double)";
          _hasTurret = data['hasTurret'] == true;
          _selectedDrivetrain = data['drivetrain']?.toString() ?? "Swerve)";

          if (data['autoPaths'] != null && data['autoPaths'] is List) {
            _allPaths = List<Map<String, dynamic>>.from(
                data['autoPaths'].map((x) => Map<String, dynamic>.from(x))
            );
          }
          if (data['photoData'] != null && data['photoData'].toString().isNotEmpty) {
            _serverImageBytes = base64Decode(data['photoData']);
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  /// 2. 提交數據 (含 Ngrok 跳過警告 Header)
  Future<void> _submitFullData() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentUserName = prefs.getString("username");

      String base64Image = "";
      if (_image != null) {
        List<int> imageBytes = await _image!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      } else if (_serverImageBytes != null) {
        base64Image = base64Encode(_serverImageBytes!);
      }

      final Map<String, dynamic> requestBody = {
        "roomName": widget.roomName,
        "teamNumber": widget.teamNumber,
        "scouterName": currentUserName ?? "Anonymous",
        "photoData": base64Image,
        "autoPaths": _allPaths,
        "description": _description,
        "drivetrain": _selectedDrivetrain,
        "maxBallCapacity": _maxBallCapacity,
        "shooterType": _shooterType,
        "hasTurret": _hasTurret,
      };

      final response = await http.post(
        Uri.parse('${Api.serverIp}/v1/pit/update-full-check'),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420", // ⭐ 關鍵：跳過 Ngrok 警告頁
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Pit Data Saved!"), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Submit Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload Failed: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 3. 圖片選取 (壓縮設定)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 25, // 壓縮圖片減少傳輸壓力
        maxWidth: 800,
      );
      if (file != null) {
        setState(() {
          _image = File(file.path);
          _serverImageBytes = null;
        });
      }
    } catch (e) {
      debugPrint("📸 Image Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(backgroundColor: bgDark, body: Center(child: CircularProgressIndicator(color: primaryCyan)));
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text("TEAM ${widget.teamNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgDark,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryCyan,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: "PHOTO"),
            Tab(icon: Icon(Icons.handyman), text: "SPEC"),
            Tab(icon: Icon(Icons.gesture), text: "PATH"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAliveWrapper(child: _buildPhotoTab()),
          _KeepAliveWrapper(child: _buildMechanicalTab()),
          _KeepAliveWrapper(child: _buildMultiPathTab()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPhotoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isSubmitting ? null : _showImageSourceSheet,
            child: Container(
              width: double.infinity,
              height: 350,
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _image != null
                    ? Image.file(_image!, fit: BoxFit.contain)
                    : (_serverImageBytes != null
                    ? Image.memory(_serverImageBytes!, fit: BoxFit.contain)
                    : Icon(Icons.add_a_photo, size: 50, color: textDim)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text("Tap to capture robot profile", style: TextStyle(color: textDim)),
        ],
      ),
    );
  }

  Widget _buildMechanicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Drivetrain Type"),
          _buildDarkDropdown(
            value: _selectedDrivetrain,
            items: ["Swerve (MK4/i)", "Tank Drive","Other"],
            onChanged: (val) => setState(() => _selectedDrivetrain = val!),
          ),
          const SizedBox(height: 20),
          _buildLabel("Max Ball Capacity"),
          _buildDarkTextField(
            initialValue: _maxBallCapacity.toString(),
            keyboardType: TextInputType.number,
            onChanged: (val) => _maxBallCapacity = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 20),
          _buildLabel("Observation Notes"),
          _buildDarkTextField(
            initialValue: _description,
            maxLines: 4,
            onChanged: (val) => _description = val,
          ),
        ],
      ),
    );
  }

  Widget _buildMultiPathTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allPaths.length + 1,
      itemBuilder: (context, index) {
        if (index == _allPaths.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton.icon(
              onPressed: () => setState(() => _allPaths.add({"name": "Auto ${index + 1}", "json": "[]"})),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("ADD NEW PATH"),
            ),
          );
        }
        return Card(
          color: cardDark,
          margin: const EdgeInsets.only(bottom: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDarkTextField(
                  initialValue: _allPaths[index]['name'],
                  onChanged: (val) => _allPaths[index]['name'] = val,
                ),
                const SizedBox(height: 12),
                BezierPathCanvas(
                  key: ValueKey("p_$index"),
                  drivetrain: _selectedDrivetrain,
                  initialJson: _allPaths[index]['json'],
                  onPathJsonChanged: (json) => _allPaths[index]['json'] = json,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helpers ---
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: TextStyle(color: primaryCyan, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _buildDarkTextField({required String initialValue, int maxLines = 1, TextInputType keyboardType = TextInputType.text, required ValueChanged<String> onChanged}) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: textLight),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black12,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryCyan)),
      ),
    );
  }

  Widget _buildDarkDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      dropdownColor: cardDark,
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: textLight)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black12,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      color: bgDark,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFullData,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isSubmitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("UPLOAD PIT DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.camera_alt, color: Colors.white), title: const Text("Camera", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library, color: Colors.white), title: const Text("Gallery", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }
}



class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});
  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}
class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) { super.build(context); return widget.child; }
  @override
  bool get wantKeepAlive => true;
}