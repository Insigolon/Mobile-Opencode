import 'dart:convert';
import 'package:http/http.dart' as http;

class OpencodeClient {
  OpencodeClient({
    required String baseUrl,
    String username = 'opencode',
    String? password,
    Duration timeout = const Duration(seconds: 15),
  })  : _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
        _timeout = timeout,
        _authHeader = password != null && password.isNotEmpty
            ? 'Basic ${base64Encode(utf8.encode('$username:$password'))}'
            : null;

  final String _baseUrl;
  final Duration _timeout;
  final String? _authHeader;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authHeader != null) 'Authorization': _authHeader!,
      };

  Map<String, String> get sseHeaders => {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        if (_authHeader != null) 'Authorization': _authHeader!,
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final res = await http
        .get(_uri(path, query), headers: _headers)
        .timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http
        .post(_uri(path),
            headers: _headers,
            body: body != null ? jsonEncode(body) : null)
        .timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> _patch(String path,
      Map<String, dynamic> body) async {
    final res = await http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<void> _delete(String path) async {
    final res = await http
        .delete(_uri(path), headers: _headers)
        .timeout(_timeout);
    if (res.statusCode >= 300) _throw(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    _throw(res);
  }

  Never _throw(http.Response res) {
    throw OpencodeApiException(
      statusCode: res.statusCode,
      message: _tryExtractMessage(res.body) ?? res.reasonPhrase ?? 'Unknown error',
      body: res.body,
    );
  }

  String? _tryExtractMessage(String body) {
    try {
      final m = jsonDecode(body);
      return m['message'] as String? ?? m['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getHealth() => _get('/global/health');

  Future<List<dynamic>> listProjects() async {
    final res = await _get('/project');
    return res['data'] as List? ?? [];
  }

  Future<Map<String, dynamic>> getCurrentProject() => _get('/project/current');

  Future<Map<String, dynamic>> getConfig() => _get('/config');

  Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> patch) =>
      _patch('/config', patch);

  Future<Map<String, dynamic>> listProviders() => _get('/config/providers');

  Future<List<dynamic>> listSessions() async {
    final res = await _get('/session');
    return res['data'] as List? ?? (res.values.first is List ? res.values.first as List : []);
  }

  Future<Map<String, dynamic>> createSession({String? title}) async {
    return _post('/session', {if (title != null) 'title': title});
  }

  Future<Map<String, dynamic>> getSession(String sessionId) =>
      _get('/session/$sessionId');

  Future<void> deleteSession(String sessionId) =>
      _delete('/session/$sessionId');

  Future<List<dynamic>> listMessages(String sessionId) async {
    final res = await _get('/session/$sessionId/message');
    return res['data'] as List? ?? (res.values.first is List ? res.values.first as List : []);
  }

  Future<Map<String, dynamic>> sendMessage(
    String sessionId,
    String content, {
    String? modelID,
    List<Map<String, dynamic>>? attachments,
  }) {
    return _post('/session/$sessionId/message', {
      'content': content,
      if (modelID != null) 'modelID': modelID,
      if (attachments != null) 'attachments': attachments,
    });
  }

  Future<Map<String, dynamic>> getPath() => _get('/path');
  Future<Map<String, dynamic>> getVcs() => _get('/vcs');

  Future<List<dynamic>> listAgents() async {
    final res = await _get('/agent');
    return res['data'] as List? ?? (res.values.first is List ? res.values.first as List : []);
  }

  String get globalEventUrl => '$_baseUrl/global/event';

  String sessionEventUrl(String sessionId) =>
      '$_baseUrl/session/$sessionId/event';

  String get apiDocUrl => '$_baseUrl/doc';
}

class OpencodeApiException implements Exception {
  const OpencodeApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'OpencodeApiException($statusCode): $message';
}
