import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DiscoveredServer {
  const DiscoveredServer({
    required this.ip,
    required this.port,
    this.hostname,
  });

  final String ip;
  final int port;
  final String? hostname;

  String get url => 'http://$ip:$port';
}

class DiscoveryService {
  Future<List<DiscoveredServer>> scan({
    int port = 4096,
    Duration timeoutPerHost = const Duration(seconds: 2),
    int maxConcurrent = 25,
  }) async {
    final subnet = await _getLocalSubnet();
    if (subnet == null) return [];

    final allIps = [for (var i = 1; i <= 254; i++) '$subnet.$i'];
    final results = <DiscoveredServer>[];
    final seen = <String>{};
    int nextIndex = 0;
    int completed = 0;
    final completer = Completer<void>();

    void onDone() {
      completed++;
      if (completed >= maxConcurrent && nextIndex >= allIps.length) {
        if (!completer.isCompleted) completer.complete();
      }
    }

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= allIps.length) {
          onDone();
          return;
        }
        final ip = allIps[index];
        final server = await _probe(ip, port, timeoutPerHost);
        if (server != null && seen.add(ip)) {
          results.add(server);
        }
      }
    }

    final workers = [for (var i = 0; i < maxConcurrent; i++) worker()];

    await Future.any([
      completer.future,
      Future.wait(workers),
    ]);

    return results;
  }

  Future<DiscoveredServer?> _probe(
    String ip,
    int port,
    Duration timeout,
  ) async {
    try {
      final url = Uri.parse('http://$ip:$port/global/health');
      final response = await http.get(url).timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['healthy'] == true) {
          return DiscoveredServer(ip: ip, port: port);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _getLocalSubnet() async {
    try {
      final skipNames = ['tailscale', 'ziti', 'vether', 'utun', 'docker', 'vmnet'];
      final skipPrefixes = ['169.', '100.', '172.'];
      final interfaces = await NetworkInterface.list();

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (skipNames.any((s) => name.contains(s))) continue;

        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            if (skipPrefixes.any((p) => ip.startsWith(p))) continue;
            final parts = ip.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
