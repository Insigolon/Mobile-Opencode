import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:opencode/agent.dart';
import 'package:opencode/services/discovery_service.dart';
import 'package:provider/provider.dart';

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
  bool scanning = false;
  String? error;
  List<DiscoveredServer>? discovered;
  final _discovery = DiscoveryService();

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

    setState(() {
      connecting = true;
      error = null;
    });

    final conn = context.read<ConnectionService>();
    final ok = await conn.connectDirect(
      baseUrl: url,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      connecting = false;
      if (ok) {
        widget.onConnected();
      } else {
        error = conn.lastError;
      }
    });
  }

  Future<void> _scanNetwork() async {
    setState(() {
      scanning = true;
      discovered = null;
      error = null;
    });

    final servers = await _discovery.scan();

    if (!mounted) return;
    setState(() {
      scanning = false;
      discovered = servers;
      if (servers.isEmpty) {
        error = 'No OpenCode servers found on this network';
      }
    });
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

  Widget _serverCard(DiscoveredServer server) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          urlController.text = server.url;
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00FF66),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.hostname ?? server.ip,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      server.url,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
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

                    if (error != null && (discovered == null || discovered!.isEmpty)) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: connecting ? null : _connect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(
                          connecting ? "Connecting..." : "Connect",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: scanning ? null : _scanNetwork,
                        icon: scanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : const Icon(Icons.wifi_find, size: 20),
                        label: Text(
                          scanning ? "Scanning..." : "Scan Network",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                      ),
                    ),

                    if (discovered != null && discovered!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Found Servers",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...discovered!.map((server) => _serverCard(server)),
                    ],

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
