import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'opencode_client.dart';

enum OpencodeEventType {
  sessionCreated,
  sessionDeleted,
  messageCreated,
  messageUpdated,
  messageCompleted,
  messageFailed,
  toolCallStart,
  toolCallEnd,
  unknown,
}

class OpencodeEvent {
  const OpencodeEvent({
    required this.type,
    required this.raw,
    this.data,
  });

  final OpencodeEventType type;
  final Map<String, dynamic>? data;
  final String raw;

  @override
  String toString() => 'OpencodeEvent($type, $data)';
}

class EventService {
  EventService({required OpencodeClient client}) : _client = client;

  final OpencodeClient _client;
  final List<http.Client> _httpClients = [];

  Stream<OpencodeEvent> get globalEvents =>
      _openStream(_client.globalEventUrl);

  Stream<OpencodeEvent> sessionEvents(String sessionId) =>
      _openStream(_client.sessionEventUrl(sessionId));

  Stream<OpencodeEvent> _openStream(String url) {
    final httpClient = http.Client();
    _httpClients.add(httpClient);

    final controller = StreamController<OpencodeEvent>.broadcast(
      onCancel: () {
        httpClient.close();
        _httpClients.remove(httpClient);
      },
    );

    _connect(url, httpClient, controller);
    return controller.stream;
  }

  Future<void> _connect(
    String url,
    http.Client httpClient,
    StreamController<OpencodeEvent> controller,
  ) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_client.sseHeaders);

      final response = await httpClient.send(request);
      if (response.statusCode != 200) {
        controller.addError(OpencodeApiException(
          statusCode: response.statusCode,
          message: 'SSE stream returned ${response.statusCode}',
        ));
        return;
      }

      final buffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final raw = buffer.toString();

        final events = raw.split('\n\n');

        buffer
          ..clear()
          ..write(events.removeLast());

        for (final block in events) {
          if (block.trim().isEmpty) continue;
          final event = _parse(block);
          if (!controller.isClosed) controller.add(event);
        }
      }
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  OpencodeEvent _parse(String block) {
    String? eventName;
    String? dataLine;

    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLine = line.substring(5).trim();
      }
    }

    Map<String, dynamic>? data;
    if (dataLine != null) {
      try {
        data = jsonDecode(dataLine) as Map<String, dynamic>;
      } catch (_) {
        data = {'raw': dataLine};
      }
    }

    return OpencodeEvent(
      type: _mapType(eventName),
      data: data,
      raw: block,
    );
  }

  OpencodeEventType _mapType(String? name) {
    switch (name) {
      case 'session.created':
        return OpencodeEventType.sessionCreated;
      case 'session.deleted':
        return OpencodeEventType.sessionDeleted;
      case 'message.created':
        return OpencodeEventType.messageCreated;
      case 'message.updated':
        return OpencodeEventType.messageUpdated;
      case 'message.completed':
        return OpencodeEventType.messageCompleted;
      case 'message.failed':
        return OpencodeEventType.messageFailed;
      case 'tool.start':
        return OpencodeEventType.toolCallStart;
      case 'tool.end':
        return OpencodeEventType.toolCallEnd;
      default:
        return OpencodeEventType.unknown;
    }
  }

  void dispose() {
    for (final c in _httpClients) {
      c.close();
    }
    _httpClients.clear();
  }
}
