import 'package:flutter/material.dart';
import 'package:opencode/agent.dart';
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
  bool tsStarting = false;

  @override
  void dispose() {
    hostController.dispose();
    portController.dispose();
    passwordController.dispose();
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

  Future<void> _startTailscale() async {
    setState(() => tsStarting = true);
    final conn = context.read<ConnectionService>();
    await conn.connectViaTailscale();
    setState(() => tsStarting = false);
  }

  Future<void> _stopTailscale() async {
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

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: tsStarting ? null : _startTailscale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5CFF),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          tsStarting ? "Starting..." : "Start Node",
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
                        onPressed: _stopTailscale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF202020),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Stop Node",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (conn.tsStatus != null)
                _tsStatusBadge(conn.tsStatus!),

              if (conn.peers.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  "Available Peers",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...conn.peers.map((peer) => _peerTile(conn, peer)),
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

  Widget _tsStatusBadge(TailscaleStatus ts) {
    final (color, label) = switch (ts.state) {
      TailscaleState.running => (Colors.greenAccent, "Running"),
      TailscaleState.starting => (Colors.yellowAccent, "Starting..."),
      TailscaleState.needsLogin => (Colors.orangeAccent, "Login Required"),
      TailscaleState.error => (Colors.redAccent, "Error"),
      TailscaleState.stopped => (Colors.grey, "Stopped"),
    };

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tailscale Node: $label",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (ts.hostname != null)
                  Text(
                    ts.hostname!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                if (ts.ipv4 != null)
                  Text(
                    ts.ipv4!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                if (ts.loginUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Open ${ts.loginUrl} in a browser to authenticate",
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _peerTile(ConnectionService conn, TailscalePeer peer) {
    final isOnline = peer.online;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isOnline
            ? () async {
                await conn.connectToPeer(peer: peer, password: passwordController.text.trim());
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            border: isOnline
                ? Border.all(color: const Color(0xFF2A2A2A))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.greenAccent : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.hostname,
                      style: TextStyle(
                        color: isOnline ? Colors.white : Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (peer.os != null)
                      Text(
                        peer.os!,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5CFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Connect",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
