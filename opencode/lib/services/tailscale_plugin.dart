import 'dart:async';
import 'package:flutter/services.dart';

enum TailscaleState { stopped, starting, running, needsLogin, error }

class TailscaleStatus {
  const TailscaleStatus({
    required this.state,
    this.hostname,
    this.tailnetName,
    this.ipv4,
    this.ipv6,
    this.loginUrl,
    this.error,
  });

  final TailscaleState state;
  final String? hostname;
  final String? tailnetName;
  final String? ipv4;
  final String? ipv6;
  final String? loginUrl;
  final String? error;

  bool get isRunning => state == TailscaleState.running;
  bool get needsLogin => state == TailscaleState.needsLogin;

  factory TailscaleStatus.fromMap(Map<dynamic, dynamic> m) {
    final stateStr = m['state'] as String? ?? 'stopped';
    return TailscaleStatus(
      state: _parseState(stateStr),
      hostname: m['hostname'] as String?,
      tailnetName: m['tailnetName'] as String?,
      ipv4: m['ipv4'] as String?,
      ipv6: m['ipv6'] as String?,
      loginUrl: m['loginUrl'] as String?,
      error: m['error'] as String?,
    );
  }

  static TailscaleState _parseState(String s) {
    switch (s) {
      case 'starting':
        return TailscaleState.starting;
      case 'running':
        return TailscaleState.running;
      case 'needsLogin':
        return TailscaleState.needsLogin;
      case 'error':
        return TailscaleState.error;
      default:
        return TailscaleState.stopped;
    }
  }

  @override
  String toString() =>
      'TailscaleStatus($state, ip=$ipv4, host=$hostname, tailnet=$tailnetName)';
}

class TailscalePlugin {
  TailscalePlugin._();
  static final TailscalePlugin instance = TailscalePlugin._();

  static const _channel = MethodChannel('dev.opencode/tailscale');
  static const _statusChannel = EventChannel('dev.opencode/tailscale/status');

  Future<TailscaleStatus> start({
    String hostname = 'opencode-mobile',
    String? authKey,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'start',
      {
        'hostname': hostname,
        if (authKey != null) 'authKey': authKey,
      },
    );
    return TailscaleStatus.fromMap(result ?? {});
  }

  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  Future<TailscaleStatus> getStatus() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getStatus');
    return TailscaleStatus.fromMap(result ?? {});
  }

  Future<String?> resolvePeer(String hostname) async {
    return _channel.invokeMethod<String>('resolvePeer', {'hostname': hostname});
  }

  Future<List<TailscalePeer>> listPeers() async {
    final raw = await _channel.invokeListMethod<Map>('listPeers');
    return (raw ?? []).map((m) => TailscalePeer.fromMap(m)).toList();
  }

  Stream<TailscaleStatus> get statusStream {
    return _statusChannel
        .receiveBroadcastStream()
        .map((event) => TailscaleStatus.fromMap(event as Map));
  }

  Future<TailscaleStatus> startAndWait({
    String hostname = 'opencode-mobile',
    String? authKey,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await start(hostname: hostname, authKey: authKey);

    return statusStream
        .where((s) =>
            s.state == TailscaleState.running ||
            s.state == TailscaleState.needsLogin ||
            s.state == TailscaleState.error)
        .first
        .timeout(
          timeout,
          onTimeout: () => throw TailscaleException(
            'Timed out waiting for Tailscale to start',
          ),
        );
  }
}

class TailscalePeer {
  const TailscalePeer({
    required this.hostname,
    required this.ipv4,
    this.ipv6,
    this.os,
    this.online = false,
  });

  final String hostname;
  final String ipv4;
  final String? ipv6;
  final String? os;
  final bool online;

  factory TailscalePeer.fromMap(Map m) => TailscalePeer(
        hostname: m['hostname'] as String? ?? '',
        ipv4: m['ipv4'] as String? ?? '',
        ipv6: m['ipv6'] as String?,
        os: m['os'] as String?,
        online: m['online'] as bool? ?? false,
      );

  String opencodeUrl({int port = 4096}) => 'http://$ipv4:$port';
}

class TailscaleException implements Exception {
  const TailscaleException(this.message);
  final String message;

  @override
  String toString() => 'TailscaleException: $message';
}
