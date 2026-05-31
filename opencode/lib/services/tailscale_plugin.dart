import 'package:flutter/services.dart';

class TailscaleStatus {
  const TailscaleStatus({
    required this.connected,
    this.tailscaleIP,
    this.error,
  });

  final bool connected;
  final String? tailscaleIP;
  final String? error;

  factory TailscaleStatus.fromMap(Map m) => TailscaleStatus(
        connected: m['connected'] as bool? ?? false,
        tailscaleIP: m['tailscaleIP'] as String?,
        error: m['error'] as String?,
      );
}

class TailscalePlugin {
  TailscalePlugin._();
  static final TailscalePlugin instance = TailscalePlugin._();

  static const _channel = MethodChannel('dev.opencode/tailscale');

  Future<bool> isInstalled() async {
    final result = await _channel.invokeMethod<bool>('isInstalled');
    return result ?? false;
  }

  Future<TailscaleStatus> connect() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('connect');
    return TailscaleStatus.fromMap(result ?? {});
  }

  Future<TailscaleStatus> disconnect() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('disconnect');
    return TailscaleStatus.fromMap(result ?? {});
  }

  Future<TailscaleStatus> getStatus() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    return TailscaleStatus.fromMap(result ?? {});
  }

  Future<String?> getTailscaleIP() async {
    final result = await _channel.invokeMethod<String>('getTailscaleIP');
    return result;
  }
}
