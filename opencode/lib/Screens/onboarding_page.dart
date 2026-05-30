import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingConnectPage extends StatefulWidget {
  final VoidCallback onConnected;

  const OnboardingConnectPage({super.key, required this.onConnected});

  @override
  State<OnboardingConnectPage> createState() => _OnboardingConnectPageState();
}

class _OnboardingConnectPageState extends State<OnboardingConnectPage> {
  final urlController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool connecting = false;
  bool connected = false;

  @override
  void dispose() {
    urlController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = urlController.text.trim();
    final password = passwordController.text.trim();
    if (url.isEmpty || password.isEmpty) return;

    setState(() => connecting = true);

    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);

    const storage = FlutterSecureStorage();
    await storage.write(key: 'server_password', value: password);

    if (!mounted) return;

    setState(() {
      connecting = false;
      connected = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    widget.onConnected();
  }

  void _showInstructions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Start server on your laptop",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'npm install -g opencode\n\n'
                  'opencode serve \\\n'
                  '  --host 0.0.0.0 \\\n'
                  '  --port 4096',
                  style: TextStyle(
                    color: Color(0xFFE6C38B),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Server URL:",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                "http://<your-laptop-ip>:4096",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080506),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    SvgPicture.asset("assets/opencode.svg", width: 340),

                    const SizedBox(height: 60),

                    TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "http://192.168.1.104:4096",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF161616),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Password / Token",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF161616),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (connecting || connected) ? null : _connect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: connected
                              ? Colors.green
                              : Colors.white,
                          foregroundColor: connected
                              ? Colors.white
                              : Colors.black,
                          disabledBackgroundColor: Colors.green,
                          disabledForegroundColor: Colors.white,
                        ),
                        child: Text(
                          connecting
                              ? "Connecting..."
                              : connected
                              ? "✓ Connected"
                              : "Connect",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => _showInstructions(context),
                      child: const Text(
                        "View Instructions",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                "love ya dax",
                style: TextStyle(color: Colors.white24, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
