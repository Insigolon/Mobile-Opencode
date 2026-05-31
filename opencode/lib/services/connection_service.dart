import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'opencode_client.dart';
import 'tailscale_plugin.dart';
import 'ziti_plugin.dart';

const _kBaseUrl  = 'opencode_base_url';
const _kUsername = 'opencode_username';
const _kPassword = 'opencode_password';
const _kZitiEnrolled = 'opencode_ziti_enrolled';
const _kZitiService  = 'opencode_ziti_service';

enum ConnectionStatus { disconnected, connecting, connected, error }
enum ConnectMode { direct, ziti, tailscale }

class ConnectionService extends ChangeNotifier {
  ConnectionService({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;
  final _ziti = ZitiPlugin.instance;
  final _tailscale = TailscalePlugin.instance;

  ConnectionStatus _status   = ConnectionStatus.disconnected;
  ConnectMode      _mode     = ConnectMode.direct;
  String?          _baseUrl;
  String           _username = 'opencode';
  String?          _lastError;
  ZitiStatus?      _zitiStatus;
  bool             _zitiEnrolled = false;
  TailscaleStatus? _tailscaleStatus;
  String?          _tailscaleIP;

  ConnectionStatus get status   => _status;
  ConnectMode      get mode     => _mode;
  String?          get baseUrl  => _baseUrl;
  String           get username => _username;
  String?          get lastError => _lastError;
  ZitiStatus?      get zitiStatus => _zitiStatus;
  bool             get zitiEnrolled => _zitiEnrolled;
  TailscaleStatus? get tailscaleStatus => _tailscaleStatus;
  String?          get tailscaleIP => _tailscaleIP;
  bool             get isConnected => _status == ConnectionStatus.connected;

  OpencodeClient? _client;
  OpencodeClient get client {
    if (_client == null) throw StateError('Not connected. Call connect() first.');
    return _client!;
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl  = prefs.getString(_kBaseUrl);
    _username = prefs.getString(_kUsername) ?? 'opencode';
    _zitiEnrolled = prefs.getBool(_kZitiEnrolled) ?? false;
    if (_baseUrl != null) {
      await connectDirect(
        baseUrl:  _baseUrl!,
        username: _username,
        password: await _secure.read(key: _kPassword),
        persist:  false,
      );
    }
  }

  Future<bool> connectDirect({
    required String baseUrl,
    String   username = 'opencode',
    String?  password,
    bool     persist  = true,
  }) async {
    _mode   = ConnectMode.direct;
    _status = ConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    final url = _normalise(baseUrl);
    try {
      final candidate = OpencodeClient(
        baseUrl:  url,
        username: username,
        password: password,
      );
      final health = await candidate.getHealth();
      if (health['healthy'] != true) throw Exception('Server reports unhealthy');

      _client   = candidate;
      _baseUrl  = url;
      _username = username;
      _status   = ConnectionStatus.connected;

      if (persist) await _saveCredentials(url, username, password);
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Could not reach server: $e';
      _status    = ConnectionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> enrollZiti(String jwtUrl) async {
    _lastError = null;
    try {
      final status = await _ziti.enroll(jwtUrl);
      _zitiStatus = status;
      if (status.error != null) {
        _lastError = status.error;
        notifyListeners();
        return false;
      }
      _zitiEnrolled = true;
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kZitiEnrolled, true);
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Ziti enrollment failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> connectViaZiti({
    String serviceName = 'opencode-svc',
    int    proxyPort   = 4095,
  }) async {
    if (!_zitiEnrolled) {
      _lastError = 'Not enrolled. Call enrollZiti() first.';
      _status    = ConnectionStatus.error;
      notifyListeners();
      return false;
    }

    _mode   = ConnectMode.ziti;
    _status = ConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      final status = await _ziti.connect();
      _zitiStatus = status;
      if (status.error != null) {
        _lastError = status.error;
        _status    = ConnectionStatus.error;
        notifyListeners();
        return false;
      }

      final p = await SharedPreferences.getInstance();
      await p.setString(_kZitiService, serviceName);

      final localUrl = 'http://localhost:$proxyPort';
      final candidate = OpencodeClient(
        baseUrl:  localUrl,
        username: _username,
        password: await _secure.read(key: _kPassword),
      );
      final health = await candidate.getHealth();
      if (health['healthy'] != true) throw Exception('Server reports unhealthy');

      _client  = candidate;
      _baseUrl = localUrl;
      _status  = ConnectionStatus.connected;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Ziti connection failed: $e';
      _status    = ConnectionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<TailscaleStatus> checkTailscale() async {
    _tailscaleStatus = await _tailscale.getStatus();
    _tailscaleIP = _tailscaleStatus?.tailscaleIP;
    notifyListeners();
    return _tailscaleStatus!;
  }

  Future<bool> connectViaTailscale({
    required String tailscaleIP,
    String  username = 'opencode',
    String? password,
    bool    persist  = true,
  }) async {
    _mode   = ConnectMode.tailscale;
    _status = ConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      await _tailscale.connect();
      // broadcast is fire-and-forget; poll until VPN is up (max ~5s)
      _tailscaleStatus = await _tailscale.getStatus();
      for (int i = 0; i < 10 && _tailscaleStatus?.connected != true; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        _tailscaleStatus = await _tailscale.getStatus();
      }

      if (_tailscaleStatus?.connected != true) {
        _lastError = 'Tailscale not connected. Open the Tailscale app to sign in.';
        _status = ConnectionStatus.error;
        notifyListeners();
        return false;
      }

      // use the laptop IP the user entered, not the auto-detected phone IP
      final url = 'http://$tailscaleIP:4096';
      _tailscaleIP = tailscaleIP;
      final candidate = OpencodeClient(
        baseUrl: url,
        username: username,
        password: password,
      );
      final health = await candidate.getHealth();
      if (health['healthy'] != true) throw Exception('Server reports unhealthy');

      _client   = candidate;
      _baseUrl  = url;
      _username = username;
      _status   = ConnectionStatus.connected;

      if (persist) await _saveCredentials(url, username, password);
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Tailscale connection failed: $e';
      _status    = ConnectionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect({bool clearCredentials = true}) async {
    if (_mode == ConnectMode.ziti) await _ziti.disconnect();
    if (_mode == ConnectMode.tailscale) {
      await _tailscale.disconnect();
      _tailscaleStatus = null;
      _tailscaleIP = null;
    }
    _client = null; _status = ConnectionStatus.disconnected;
    _lastError = null; _zitiStatus = null;
    if (clearCredentials) {
      await _clearCredentials();
      _baseUrl = null; _username = 'opencode'; _zitiEnrolled = false;
    }
    notifyListeners();
  }

  String _normalise(String url) {
    var u = url.trim().replaceAll(RegExp(r'/$'), '');
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    return u;
  }

  Future<void> _saveCredentials(String url, String username, String? password) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaseUrl, url);
    await p.setString(_kUsername, username);
    if (password?.isNotEmpty == true) {
      await _secure.write(key: _kPassword, value: password!);
    } else {
      await _secure.delete(key: _kPassword);
    }
  }

  Future<void> _clearCredentials() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBaseUrl);
    await p.remove(_kUsername);
    await p.remove(_kZitiEnrolled);
    await p.remove(_kZitiService);
    await _secure.delete(key: _kPassword);
  }
}
