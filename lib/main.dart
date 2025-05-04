import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logging/logging.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveData(String username, String password, bool isConnected) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('username', username);
  await prefs.setString('password', password);
  await prefs.setBool('isConnected', isConnected);
}

Future<void> loadData() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? username = prefs.getString('username');
  String? password = prefs.getString('password');
  bool isConnected = prefs.getBool('isConnected') ?? false;

  // Cek apakah data ada dan coba untuk terhubung kembali ke server
  if (username != null && password != null && isConnected) {
    // Logika untuk mencoba kembali koneksi menggunakan username dan password
    // Misalnya, koneksi ke server dengan kredensial yang telah disimpan
  }
}


void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Fan Control',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        cardColor: Colors.white,
        primaryColor: Colors.teal,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        cardColor: const Color(0xFF2A2A40),
        primaryColor: Colors.tealAccent,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
        ),
      ),
      home:
          MqttControlPage(onThemeChanged: _toggleTheme, themeMode: _themeMode),
    );
  }
}

// Fungsi untuk menyimpan data saat login
void saveLoginData(String username, String password) {
  bool isConnected = true; // Asumsi koneksi berhasil
  saveData(username, password, isConnected);
}

// Fungsi untuk memuat data saat aplikasi dimulai
void checkLoginStatus() {
  loadData();
}


class MqttControlPage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final ThemeMode themeMode;

  const MqttControlPage({
    super.key,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  State<MqttControlPage> createState() => _MqttControlPageState();
}

class _MqttControlPageState extends State<MqttControlPage>
    with SingleTickerProviderStateMixin {
  final _logger = Logger('MQTT');
  final client = MqttServerClient('yusuftech.my.id', 'flutter_client');
  final topic = 'fan/control';

  bool isPowerOn = false;
  bool isFanAnimationOn = false; // Tambahkan status animasi kipas
  bool isConnected = true;
  String speedStatus = "0";
  String connectStatus = "Connecting...";
  Color statusColor = Colors.orange;

  String mqttHost = 'example.com'; // Default host
  String mqttUser = 'user'; // Default username
  String mqttPassword = 'pass'; // Default password

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat();
    _connect();
  }

  @override
  void dispose() {
    _controller.dispose();
    client.disconnect();
    super.dispose();
  }

  void _connect() async {
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.logging(on: false);
    client.onDisconnected = () {
      setState(() {
        isConnected = false;
        connectStatus = "Disconnected";
        statusColor = Colors.red;
      });
    };

    // Menggunakan username yang telah dimasukkan dan menambahkan '_client' untuk clientId
    final clientId =
        '${mqttUser}_client'; // clientId sekarang berdasarkan username

    // Menggunakan kredensial yang baru setelah disimpan
    final connectionMessage = MqttConnectMessage()
        .withClientIdentifier(
            clientId) // Menggunakan clientId berdasarkan username
        .authenticateAs(mqttUser,
            mqttPassword) // Menggunakan username dan password yang baru
        .startClean();

    client.connectionMessage = connectionMessage;

    try {
      await client.connect();
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        setState(() {
          isConnected = true;
          connectStatus = "Connected";
          statusColor = Colors.green;
        });
      } else {
        _logger.warning(
            'Connection failed with status: ${client.connectionStatus}');
        setState(() {
          isConnected = false;
          connectStatus = "Connection Failed";
          statusColor = Colors.red;
        });
      }
    } catch (e) {
      _logger.warning('Connection error: $e');
      client.disconnect();
      setState(() {
        isConnected = false;
        connectStatus = "Disconnected";
        statusColor = Colors.red;
      });
    }
  }

  void _publish(String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  double _rotationMultiplier() {
    switch (speedStatus) {
      case "1":
        return 20;
      case "2":
        return 25;
      case "3":
        return 30;
      default:
        return 0;
    }
  }

void _togglePower() {
  if (!isConnected) return; // Tambahkan ini agar tidak bisa diklik jika tidak konek

  setState(() {
    isPowerOn = !isPowerOn;
    if (isPowerOn) {
      _publish("power/on");
    } else {
      _publish("power/off");
      speedStatus = "0"; // Reset speed when turning off
    }
  });
}


void _setSpeed(String speed) {
  if (!isConnected) return;

  setState(() {
    speedStatus = speed;
    _publish("speed/$speed");
  });
}

void _toggleFanAnimation() {
  if (!isConnected) return;

  setState(() {
    isFanAnimationOn = !isFanAnimationOn;
    String message = isFanAnimationOn ? "rotate/on" : "rotate/off";
    _publish(message);
  });
}



  void _showSettingsDialog() {
    TextEditingController hostController =
        TextEditingController(text: mqttHost);
    TextEditingController userController =
        TextEditingController(text: mqttUser);
    TextEditingController passController =
        TextEditingController(text: mqttPassword);

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context); // Get the current theme
        final isDark =
            theme.brightness == Brightness.dark; // Check if the theme is dark
        return AlertDialog(
          title: Text(
            'MQTT Server Configuration',
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: "JetBrains Mono",
              fontSize: 20,
              color: isDark
                  ? Colors.white
                  : Colors.black, // Adjust title color based on theme
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostController,
                decoration: InputDecoration(
                  labelText: 'Host',
                  labelStyle: TextStyle(
                    fontFamily: "JetBrains Mono",
                    fontSize: 15,
                    color: isDark
                        ? Colors.white
                        : Colors.black, // Adjust label color
                  ),
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: "JetBrains Mono",
                  fontSize: 15,
                  color:
                      isDark ? Colors.white : Colors.black, // Adjust text color
                ),
              ),
              TextField(
                controller: userController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(
                    fontFamily: "JetBrains Mono",
                    fontSize: 15,
                    color: isDark
                        ? Colors.white
                        : Colors.black, // Adjust label color
                  ),
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: "JetBrains Mono",
                  fontSize: 15,
                  color:
                      isDark ? Colors.white : Colors.black, // Adjust text color
                ),
              ),
              TextField(
                controller: passController,
                obscureText: true, // Password hidden by default
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    fontFamily: "JetBrains Mono",
                    fontSize: 15,
                    color: isDark
                        ? Colors.white
                        : Colors.black, // Adjust label color
                  ),
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: "JetBrains Mono",
                  fontSize: 15,
                  color:
                      isDark ? Colors.white : Colors.black, // Adjust text color
                ),
              ),
            ],
          ),
          actions: [
 
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: "JetBrains Mono",
                  fontSize: 15,
                  color: isDark
                      ? Colors.white
                      : Colors.black, // Adjust button text color
                ),
              ),
            ),
                       TextButton(
              onPressed: () {
                setState(() {
                  mqttHost = hostController.text;
                  mqttUser = userController.text;
                  mqttPassword = passController.text;
                });

                // Putuskan koneksi lama sebelum menghubungkan kembali dengan kredensial baru
                client.disconnect();

                // Cobalah untuk menghubungkan kembali dengan kredensial yang baru
                _connect();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Configuration saved successfully')),
                );

              },
              child: Text(
                'Save',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: "JetBrains Mono",
                  fontSize: 15,
                  color: isDark
                      ? Colors.white
                      : Colors.black, // Adjust button text color
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(fontFamily: 'JetBrains Mono')),
      backgroundColor: color.withAlpha((0.2 * 255).toInt()),
      labelStyle: TextStyle(color: color),
      avatar: CircleAvatar(backgroundColor: color, radius: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Fan",
            style: TextStyle(fontFamily: "JetBrains Mono")),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Switch(
            value: isDark,
            onChanged: (value) => widget.onThemeChanged(value),
            activeColor: theme.primaryColor,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: ListView(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // Menjaga elemen di kiri
                  children: [
                    // Text "Server" di kiri
                    Text(
                      'Server:',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: "JetBrains Mono",
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    Spacer(), // Mengambil ruang kosong agar status bisa di tengah
                    // Menampilkan status (misalnya "Disconnected") di tengah
                    _buildStatusChip(connectStatus, statusColor),
                    Spacer(), // Mengambil ruang kosong agar status bisa di tengah
                    // Tombol refresh dan pengaturan di kanan
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.refresh, color: theme.primaryColor),
                          onPressed: () {
                            setState(() {
                              connectStatus = "Reconnecting...";
                              statusColor = Colors.orange;
                            });
                            _connect();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.settings, color: theme.primaryColor),
                          onPressed: _showSettingsDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 50),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => isPowerOn
                    ? Transform.rotate(
                        angle:
                            _controller.value * 2 * pi * _rotationMultiplier(),
                        child: CustomPaint(
                          size: const Size(200, 200),
                          painter: FanPainter(isDarkMode: isDark),
                        ),
                      )
                    : CustomPaint(
                        size: const Size(200, 200),
                        painter: FanPainter(isDarkMode: isDark),
                      ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _togglePower,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPowerOn
                            ? theme.primaryColor
                            : Colors.transparent, // Add border when active
                        width: 3, // Set border width
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(77),
                          offset: const Offset(4, 4),
                          blurRadius: 10, // Menonjolkan shadow lebih dalam
                        ),
                        BoxShadow(
                          color: Colors.white.withAlpha(13),
                          offset: const Offset(-4, -4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    padding:
                        const EdgeInsets.all(15), // Padding untuk efek inset
                    child: Icon(
                      Icons.power_settings_new,
                      color: isPowerOn ? theme.primaryColor : Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(
                    width:
                        50), // Spasi antara tombol power dan tombol animasi kipas
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _toggleFanAnimation(); // ubah status tombol (mulai / berhenti animasi)
                      // Mengirimkan pesan MQTT berdasarkan status animasi
                      String message =
                          isFanAnimationOn ? "rotate/on" : "rotate/off";
                      _publish(message); // kirim pesan ke MQTT
                    });
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFanAnimationOn
                            ? theme.primaryColor
                            : Colors.transparent, // border aktif
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(77),
                          offset: const Offset(4, 4),
                          blurRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.white.withAlpha(13),
                          offset: const Offset(-4, -4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(15),
                    child: Icon(
                      Icons.rotate_right,
                      color:
                          isFanAnimationOn ? theme.primaryColor : Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _speedButton("1", theme),
                _speedButton("2", theme),
                _speedButton("3", theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedButton(String speed, ThemeData theme) {
    final isSelected = speed == speedStatus;
    return GestureDetector(
      onTap: () {
        if (isPowerOn) _setSpeed(speed);
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.cardColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : Colors.transparent, // Add border when active
            width: 3, // Set border width
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              offset: const Offset(4, 4),
              blurRadius: 10, // Menonjolkan shadow lebih dalam
            ),
            BoxShadow(
              color: Colors.white.withAlpha(13),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(15), // Padding untuk efek inset
        child: Center(
          child: Text(
            speed,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              fontFamily: "JetBrains Mono",
              color: isSelected ? theme.primaryColor : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}

class FanPainter extends CustomPainter {
  final bool isDarkMode;

  FanPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final length = size.width / 2.5;
    final radius = size.width / 2.2;

    // Gambar lingkaran dalam kipas (bagian poros)
    final innerFillPaint = Paint()
      ..color = isDarkMode
          ? const Color.fromARGB(110, 66, 66, 66)
          : const Color.fromARGB(111, 240, 240, 240)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, innerFillPaint);

    // Gambar casing kipas
    final casingPaint = Paint()
      ..color = isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, casingPaint);

    // Gambar baling-baling kipas
    final bladePaint = Paint()
      ..color = isDarkMode ? Colors.teal : Colors.blueAccent
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final angle = (2 * pi / 3) * i;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + length * cos(angle - 0.2),
            center.dy + length * sin(angle - 0.2))
        ..arcTo(
          Rect.fromCircle(center: center, radius: size.width / 2.5),
          angle - 0.2,
          0.4,
          false,
        )
        ..lineTo(center.dx + length * cos(angle + 0.2),
            center.dy + length * sin(angle + 0.2))
        ..close();
      canvas.drawPath(path, bladePaint);
    }

    // Gambar titik hitam di tengah kipas
    final centerCirclePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        center, 10, centerCirclePaint); // Titik hitam di tengah kipas
  }

  @override
  bool shouldRepaint(covariant FanPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}
