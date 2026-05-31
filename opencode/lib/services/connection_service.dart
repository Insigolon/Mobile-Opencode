import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'opencode_client.dart';
import 'tailscale_plugin.dart';

const _kBaseUrl    = 'opencode_base_url';
const _kUsername   = 'opencode_username';
const _kPassword   = 'opencode_password';
const _kTsHostname = 'opencode_ts_peer_hostname';
const _kTsPort     = 'opencode_ts_port';

enum ConnectionStatus { disconnected, connecting, connected, error }
enum ConnectMode { direct, tailscale }

class ConnectionService extends ChangeNotifier {
  ConnectionService({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;
  final _ts = TailscalePlugin.instance;

  ConnectionStatus _status   = ConnectionStatus.disconnected;
  ConnectMode      _mode     = ConnectMode.direct;
  String?          _baseUrl;
  String           _username = 'opencode';
  String?          _lastError;
  TailscaleStatus? _tsStatus;
  List<TailscalePeer> _peers = [];

  ConnectionStatus     get status   => _status;
  ConnectMode          get mode     => _mode;
  String?              get baseUrl  => _baseUrl;
  String               get username => _username;
  String?              get lastError => _lastError;
  TailscaleStatus?     get tsStatus => _tsStatus;
  List<TailscalePeer>  get peers    => List.unmodifiable(_peers);
  bool                 get isConnected => _status == ConnectionStatus.connected;

  OpencodeClient? _client;
  OpencodeClient get client {
    if (_client == null) throw StateError('Not connected. Call connect() first.');
    return _client!;
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl  = prefs.getString(_kBaseUrl);
    _username = prefs.getString(_kUsername) ?? 'opencode';
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

  Future<bool> connectViaTailscale({
    String?  peerHostname,
    String?  authKey,
    String?  password,
    int      port     = 4096,
    bool     persist  = true,
  }) async {
    _mode      = ConnectMode.tailscale;
    _status    = ConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      final ts = await _ts.startAndWait(
        hostname: 'opencode-mobile',
        authKey:  authKey,
      );
      _tsStatus = ts;
      notifyListeners();

      if (ts.needsLogin) {
        _lastError = 'Login required — open loginUrl in a browser';
        _status    = ConnectionStatus.error;
        notifyListeners();
        return false;
      }

      if (!ts.isRunning) {
        _lastError = ts.error ?? 'Tailscale failed to start';
        _status    = ConnectionStatus.error;
        notifyListeners();
        return false;
      }

      _ts.statusStream.listen((s) { _tsStatus = s; notifyListeners(); });

      _peers = await _ts.listPeers();
      notifyListeners();

      if (peerHostname == null) {
        _status = ConnectionStatus.connecting;
        notifyListeners();
        return true;
      }

      final peerIp = await _ts.resolvePeer(peerHostname);
      if (peerIp == null) {
        _lastError = 'Peer "$peerHostname" not found on tailnet';
        _status    = ConnectionStatus.error;
        notifyListeners();
        return false;
      }

      return connectToPeer(
        peer:     TailscalePeer(hostname: peerHostname, ipv4: peerIp),
        password: password,
        port:     port,
        persist:  persist,
      );
    } catch (e) {
      _lastError = 'Tailscale error: $e';
      _status    = ConnectionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> connectToPeer({
    required TailscalePeer peer,
    String?  password,
    int      port    = 4096,
    bool     persist = true,
  }) async {
    final ok = await connectDirect(
      baseUrl:  peer.opencodeUrl(port: port),
      password: password,
      persist:  persist,
    );
    if (ok && persist) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kTsHostname, peer.hostname);
      await p.setInt(_kTsPort, port);
    }
    return ok;
  }

  Future<void> disconnect({bool clearCredentials = true}) async {
    if (_mode == ConnectMode.tailscale) await _ts.stop();
    _client = null; _status = ConnectionStatus.disconnected;
    _lastError = null; _tsStatus = null; _peers = [];
    if (clearCredentials) {
      await _clearCredentials();
      _baseUrl = null; _username = 'opencode';
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
    for (final k in [_kBaseUrl, _kUsername, _kTsHostname]) { await p.remove(k); }
    await p.remove(_kTsPort);
    await _secure.delete(key: _kPassword);
  }
}
