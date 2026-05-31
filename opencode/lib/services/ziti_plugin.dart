import 'package:flutter/services.dart';

class ZitiStatus {
  const ZitiStatus({
    required this.enrolled,
    required this.connected,
    this.error,
  });

  final bool enrolled;
  final bool connected;
  final String? error;

  factory ZitiStatus.fromMap(Map m) => ZitiStatus(
        enrolled: m['enrolled'] as bool? ?? false,
        connected: m['connected'] as bool? ?? false,
        error: m['error'] as String?,
      );
}

class ZitiPlugin {
  ZitiPlugin._();
  static final ZitiPlugin instance = ZitiPlugin._();

  static const _channel = MethodChannel('dev.opencode/ziti');

  Future<ZitiStatus> enroll(String jwtUrl) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'enroll',
      {'jwtUrl': jwtUrl},
    );
    return ZitiStatus.fromMap(result ?? {});
  }

  Future<ZitiStatus> connect() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('connect');
    return ZitiStatus.fromMap(result ?? {});
  }

  Future<ZitiStatus> getStatus() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    return ZitiStatus.fromMap(result ?? {});
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
  }
}
