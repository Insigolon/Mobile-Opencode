import 'package:flutter/material.dart';
import 'package:opencode/agent.dart';
import 'package:opencode/services/discovery_service.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final hostController = TextEditingController(text: "0.0.0.0");
  final portController = TextEditingController(text: "4096");
  final passwordController = TextEditingController();
  final jwtUrlController = TextEditingController();
  final tailscaleIPController = TextEditingController();
  bool zitiBusy = false;
  bool tailscaleBusy = false;
  bool scanBusy = false;
  final _discovery = DiscoveryService();

  @override
  void dispose() {
    hostController.dispose();
    portController.dispose();
    passwordController.dispose();
    jwtUrlController.dispose();
    tailscaleIPController.dispose();
    super.dispose();
  }

  Future<void> _connectDirect() async {
    final conn = context.read<ConnectionService>();
    await conn.connectDirect(
      baseUrl: '${hostController.text.trim()}:${portController.text.trim()}',
      password: passwordController.text.trim(),
    );
  }

  Future<void> _disconnect() async {
    await context.read<ConnectionService>().disconnect();
  }

  Future<void> _scanNetwork() async {
    setState(() => scanBusy = true);
    final servers = await _discovery.scan();
    if (!mounted) return;
    setState(() => scanBusy = false);
    if (servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No OpenCode servers found")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: servers.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.computer, color: Color(0xFF00FF66)),
              title: Text(servers[i].ip,
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(servers[i].url,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                hostController.text = servers[i].ip;
                portController.text = servers[i].port.toString();
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _enrollZiti() async {
    setState(() => zitiBusy = true);
    final conn = context.read<ConnectionService>();
    await conn.enrollZiti(jwtUrlController.text.trim());
    setState(() => zitiBusy = false);
  }

  Future<void> _connectZiti() async {
    setState(() => zitiBusy = true);
    final conn = context.read<ConnectionService>();
    await conn.connectViaZiti();
    setState(() => zitiBusy = false);
  }

  Future<void> _disconnectZiti() async {
    final conn = context.read<ConnectionService>();
    if (conn.mode == ConnectMode.ziti) {
      await conn.disconnect();
    }
  }

  Future<void> _checkTailscale() async {
    setState(() => tailscaleBusy = true);
    final conn = context.read<ConnectionService>();
    await conn.checkTailscale();
    setState(() => tailscaleBusy = false);
  }

  Future<void> _connectTailscale() async {
    setState(() => tailscaleBusy = true);
    final conn = context.read<ConnectionService>();
    await conn.connectViaTailscale(
      tailscaleIP: tailscaleIPController.text.trim(),
      password: passwordController.text.trim(),
    );
    setState(() => tailscaleBusy = false);
  }

  Future<void> _disconnectTailscale() async {
    final conn = context.read<ConnectionService>();
    if (conn.mode == ConnectMode.tailscale) {
      await conn.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionService>();

    return Scaffold(
      backgroundColor: const Color(0xFF080506),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD9D9D9),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Account Name",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conn.baseUrl ?? "Not connected",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              const Text(
                "Server Connection",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "Direct Connection",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              const Text("Hostname", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: hostController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161616),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Port", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: portController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161616),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Password", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161616),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _connectDirect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          "Connect",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _disconnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF202020),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Disconnect",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: scanBusy ? null : _scanNetwork,
                  icon: scanBusy
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
                    scanBusy ? "Scanning..." : "Scan Network",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Divider(color: Colors.white24),
              const SizedBox(height: 24),

              const Text(
                "OpenZiti",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              const Text("Enrollment JWT URL", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: jwtUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161616),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: "http://laptop-ip:8080/enroll.jwt",
                  hintStyle: const TextStyle(color: Colors.white24),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: zitiBusy ? null : _enrollZiti,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5CFF),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          zitiBusy ? "Working..." : "Enroll",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (zitiBusy || !conn.zitiEnrolled) ? null : _connectZiti,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5CFF),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Connect",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _disconnectZiti,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF202020),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Disconnect",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (conn.zitiStatus != null) ...[
                const SizedBox(height: 16),
                _zitiStatusBadge(conn),
              ],

              if (conn.lastError != null && conn.mode == ConnectMode.ziti) ...[
                const SizedBox(height: 12),
                Text(
                  conn.lastError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const SizedBox(height: 40),
              const Divider(color: Colors.white24),
              const SizedBox(height: 24),

              const Text(
                "Tailscale",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              const Text("Tailscale IP", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: tailscaleIPController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF161616),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: "laptop Tailscale IP (e.g. 100.x.x.x)",
                  hintStyle: const TextStyle(color: Colors.white24),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: tailscaleBusy ? null : _checkTailscale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          tailscaleBusy ? "Checking..." : "Check Status",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: tailscaleBusy ? null : _connectTailscale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          tailscaleBusy ? "Working..." : "Connect",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _disconnectTailscale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF202020),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Disconnect",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (conn.tailscaleStatus != null) ...[
                const SizedBox(height: 16),
                _tailscaleStatusBadge(conn),
              ],

              if (conn.lastError != null && conn.mode == ConnectMode.tailscale) ...[
                const SizedBox(height: 12),
                Text(
                  conn.lastError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const SizedBox(height: 32),

              _statusIndicator(conn),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  "OpenCode Mobile",
                  style: TextStyle(color: Colors.white24, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zitiStatusBadge(ConnectionService conn) {
    final zs = conn.zitiStatus!;
    final (color, label) = switch ((zs.enrolled, zs.connected)) {
      (true, true) => (Colors.greenAccent, "Connected"),
      (true, false) => (Colors.yellowAccent, "Enrolled"),
      (false, _) => (Colors.grey, "Not Enrolled"),
    };
    if (zs.error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          zs.error!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "OpenZiti: $label",
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _tailscaleStatusBadge(ConnectionService conn) {
    final ts = conn.tailscaleStatus!;
    final (color, label) = switch ((ts.connected, ts.tailscaleIP)) {
      (true, _) => (Colors.greenAccent, "Connected (${ts.tailscaleIP ?? ""})"),
      (false, _) => (Colors.grey, "Not Connected"),
    };
    if (ts.error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          ts.error!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Tailscale: $label",
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _statusIndicator(ConnectionService conn) {
    final (color, label) = switch (conn.status) {
      ConnectionStatus.connected => (Colors.green, "Connected"),
      ConnectionStatus.connecting => (Colors.yellowAccent, "Connecting..."),
      ConnectionStatus.disconnected => (Colors.red, "Disconnected"),
      ConnectionStatus.error => (Colors.redAccent, "Error"),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          if (conn.mode == ConnectMode.ziti) ...[
            const SizedBox(width: 8),
            const Text(
              "(Ziti)",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          if (conn.mode == ConnectMode.tailscale) ...[
            const SizedBox(width: 8),
            const Text(
              "(Tailscale)",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
