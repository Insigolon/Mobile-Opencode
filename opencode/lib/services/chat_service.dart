import 'dart:async';
import 'package:flutter/foundation.dart';
import 'opencode_client.dart';
import 'event_service.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? createdAt;

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? 'Untitled',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

enum MessageRole { user, assistant, tool }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.createdAt,
    this.isStreaming = false,
  });

  final String id;
  final String sessionId;
  final MessageRole role;
  String content;
  final DateTime? createdAt;
  bool isStreaming;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: j['sessionID'] as String? ?? '',
        role: _parseRole(j['role'] as String?),
        content: _extractContent(j),
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );

  static MessageRole _parseRole(String? r) {
    switch (r) {
      case 'assistant':
        return MessageRole.assistant;
      case 'tool':
        return MessageRole.tool;
      default:
        return MessageRole.user;
    }
  }

  static String _extractContent(Map<String, dynamic> j) {
    final parts = j['parts'] as List?;
    if (parts != null) {
      return parts
          .whereType<Map>()
          .map((p) => p['text'] as String? ?? '')
          .join();
    }
    return j['text'] as String? ?? j['content'] as String? ?? '';
  }
}

class ChatService extends ChangeNotifier {
  ChatService({
    required OpencodeClient client,
    required EventService events,
  })  : _client = client,
        _events = events;

  final OpencodeClient _client;
  final EventService _events;

  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  final Map<String, List<ChatMessage>> _messages = {};
  List<ChatMessage> messagesFor(String sessionId) =>
      List.unmodifiable(_messages[sessionId] ?? []);

  bool _isSending = false;
  bool get isSending => _isSending;

  StreamSubscription<OpencodeEvent>? _globalSub;
  StreamSubscription<OpencodeEvent>? _sessionSub;

  Future<void> init() async {
    await refreshSessions();
    _subscribeGlobal();
  }

  Future<void> refreshSessions() async {
    final raw = await _client.listSessions();
    _sessions = raw
        .whereType<Map<String, dynamic>>()
        .map(ChatSession.fromJson)
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    notifyListeners();
  }

  Future<ChatSession> createSession({String? title}) async {
    final json = await _client.createSession(title: title);
    final session = ChatSession.fromJson(json);
    _sessions.insert(0, session);
    notifyListeners();
    return session;
  }

  Future<void> deleteSession(String id) async {
    await _client.deleteSession(id);
    _sessions.removeWhere((s) => s.id == id);
    _messages.remove(id);
    if (_activeSessionId == id) {
      _activeSessionId = null;
      _sessionSub?.cancel();
    }
    notifyListeners();
  }

  Future<void> setActiveSession(String sessionId) async {
    if (_activeSessionId == sessionId) return;

    _sessionSub?.cancel();
    _activeSessionId = sessionId;
    notifyListeners();

    await _loadMessages(sessionId);
    _subscribeSession(sessionId);
  }

  Future<void> _loadMessages(String sessionId) async {
    final raw = await _client.listMessages(sessionId);
    _messages[sessionId] = raw
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? modelId}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) throw StateError('No active session');
    if (text.trim().isEmpty) return;

    _isSending = true;

    final optimistic = ChatMessage(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      role: MessageRole.user,
      content: text,
    );
    _messages.putIfAbsent(sessionId, () => []).add(optimistic);
    notifyListeners();

    try {
      await _client.sendMessage(sessionId, text, modelID: modelId);
    } catch (_) {
      _messages[sessionId]?.remove(optimistic);
      rethrow;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _subscribeGlobal() {
    _globalSub = _events.globalEvents.listen(_handleGlobalEvent);
  }

  void _subscribeSession(String sessionId) {
    _sessionSub =
        _events.sessionEvents(sessionId).listen(_handleSessionEvent);
  }

  void _handleGlobalEvent(OpencodeEvent event) {
    switch (event.type) {
      case OpencodeEventType.sessionCreated:
        final data = event.data;
        if (data != null) {
          final s = ChatSession.fromJson(data);
          if (!_sessions.any((x) => x.id == s.id)) {
            _sessions.insert(0, s);
            notifyListeners();
          }
        }
        break;
      case OpencodeEventType.sessionDeleted:
        final id = event.data?['id'] as String?;
        if (id != null) {
          _sessions.removeWhere((s) => s.id == id);
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  void _handleSessionEvent(OpencodeEvent event) {
    final sid = _activeSessionId;
    if (sid == null) return;
    final msgs = _messages.putIfAbsent(sid, () => []);

    switch (event.type) {
      case OpencodeEventType.messageCreated:
        if (event.data != null) {
          final msg = ChatMessage.fromJson(event.data!);
          final optimisticIdx =
              msgs.indexWhere((m) => m.id.startsWith('pending-') && m.role == MessageRole.user && m.content == msg.content);
          if (optimisticIdx >= 0) {
            msgs[optimisticIdx] = msg;
          } else if (!msgs.any((m) => m.id == msg.id)) {
            msgs.add(msg);
          }
          notifyListeners();
        }
        break;

      case OpencodeEventType.messageUpdated:
        if (event.data != null) {
          final incoming = ChatMessage.fromJson(event.data!);
          final idx = msgs.indexWhere((m) => m.id == incoming.id);
          if (idx >= 0) {
            msgs[idx].content = incoming.content;
            msgs[idx].isStreaming = true;
          } else {
            msgs.add(incoming..isStreaming = true);
          }
          notifyListeners();
        }
        break;

      case OpencodeEventType.messageCompleted:
        if (event.data != null) {
          final incoming = ChatMessage.fromJson(event.data!);
          final idx = msgs.indexWhere((m) => m.id == incoming.id);
          if (idx >= 0) {
            msgs[idx].content = incoming.content;
            msgs[idx].isStreaming = false;
          }
          notifyListeners();
        }
        break;

      case OpencodeEventType.messageFailed:
        for (final m in msgs) {
          m.isStreaming = false;
        }
        notifyListeners();
        break;

      default:
        break;
    }
  }

  @override
  void dispose() {
    _globalSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }
}
