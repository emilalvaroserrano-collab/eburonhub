import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'runtime.dart';
import 'storage.dart';

typedef ChatStreamHandler = Stream<String> Function(
  String prompt,
  String? systemPrompt,
  List<Map<String, String>> history,
  CancellationToken cancellationToken,
);

class LocalApiServer {
  LocalApiServer({
    required List<ModelDescriptor> Function() models,
    required Future<List<RuntimeHealth>> Function() runtimeHealth,
    ChatStreamHandler? chat,
  })  : _models = models,
        _runtimeHealth = runtimeHealth,
        _chat = chat;

  final List<ModelDescriptor> Function() _models;
  final Future<List<RuntimeHealth>> Function() _runtimeHealth;
  ChatStreamHandler? _chat;
  HttpServer? _server;
  AppSettings _settings = const AppSettings();
  final StreamController<ServerActivity> _activity =
      StreamController<ServerActivity>.broadcast();
  final Map<String, _RateBucket> _rateBuckets = {};

  bool get running => _server != null;
  int? get port => _server?.port;
  Stream<ServerActivity> get activity => _activity.stream;

  void setChatHandler(ChatStreamHandler? handler) => _chat = handler;

  Future<String?> lanUrl() async {
    final serverPort = _server?.port ?? _settings.serverPort;
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return 'http://${address.address}:$serverPort';
      }
    }
    return null;
  }

  Future<void> start(AppSettings settings) async {
    if (running) return;
    _settings = settings;
    final bindAddress = settings.lanAccess
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4;
    _server = await HttpServer.bind(bindAddress, settings.serverPort);
    unawaited(_serve(_server!));
  }

  Future<void> stop() async {
    final current = _server;
    _server = null;
    await current?.close(force: true);
  }

  Future<void> restart(AppSettings settings) async {
    await stop();
    await start(settings);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final requestId = '${DateTime.now().microsecondsSinceEpoch}-${request.hashCode}';
    final started = DateTime.now();
    _activity.add(ServerActivity(requestId, request.method, request.uri.path, true));

    try {
      _applyCors(request.response);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      if (!_authorized(request)) {
        await _json(request.response, HttpStatus.unauthorized, {
          'error': {
            'message': 'Invalid or missing API key',
            'type': 'authentication_error',
          }
        });
        return;
      }
      if (!_allowRequest(request)) {
        await _json(request.response, HttpStatus.tooManyRequests, {
          'error': {
            'message': 'Rate limit exceeded',
            'type': 'rate_limit_error',
          }
        });
        return;
      }

      final path = request.uri.path;
      if (request.method == 'GET' && path == '/health') {
        final health = await _runtimeHealth();
        await _json(request.response, HttpStatus.ok, {
          'status': 'ok',
          'server': 'eburon-hub',
          'runtime': health
              .map((e) => {
                    'name': e.runtime.wireName,
                    'available': e.available,
                    'version': e.version,
                    'message': e.message,
                  })
              .toList(),
        });
      } else if (request.method == 'GET' && path == '/v1/models') {
        await _modelsEndpoint(request.response);
      } else if (request.method == 'GET' &&
          path == '/v1/server/capabilities') {
        await _capabilitiesEndpoint(request.response);
      } else if (request.method == 'POST' &&
          (path == '/v1/chat/completions' || path == '/v1/completions')) {
        await _chatEndpoint(request, legacyCompletion: path == '/v1/completions');
      } else if (request.method == 'POST' && path == '/v1/audio/transcriptions') {
        await _notReady(request.response, 'STT native adapter');
      } else if (request.method == 'POST' && path == '/v1/audio/speech') {
        await _notReady(request.response, 'TTS native adapter');
      } else if (request.method == 'POST' &&
          (path == '/v1/images/generations' || path == '/v1/images/edits')) {
        await _notReady(request.response, 'stable-diffusion.cpp adapter');
      } else if (path == '/v1/realtime/transcription' ||
          path == '/v1/realtime/speech') {
        await _realtimeSocket(request);
      } else {
        await _json(request.response, HttpStatus.notFound, {
          'error': {
            'message': 'Route not found: ${request.method} $path',
            'type': 'invalid_request_error',
          }
        });
      }
    } catch (error) {
      if (!request.response.headersSent) {
        await _json(request.response, HttpStatus.internalServerError, {
          'error': {
            'message': error.toString(),
            'type': 'server_error',
          }
        });
      } else {
        await request.response.close();
      }
    } finally {
      _activity.add(ServerActivity(
        requestId,
        request.method,
        request.uri.path,
        false,
        duration: DateTime.now().difference(started),
      ));
    }
  }

  bool _authorized(HttpRequest request) {
    if (!_settings.requireApiKey) return true;
    final expected = _settings.apiKey.trim();
    if (expected.isEmpty) return false;
    final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return auth == 'Bearer $expected';
  }

  bool _allowRequest(HttpRequest request) {
    final key = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final now = DateTime.now();
    final current = _rateBuckets[key];
    if (current == null || now.difference(current.started) >= const Duration(minutes: 1)) {
      _rateBuckets[key] = _RateBucket(now, 1);
      return true;
    }
    if (current.count >= 120) return false;
    current.count++;
    return true;
  }

  void _applyCors(HttpResponse response) {
    if (!_settings.cors) return;
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'Authorization, Content-Type')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  }

  Future<void> _modelsEndpoint(HttpResponse response) async {
    final data = _models()
        .map((model) => {
              'id': model.id,
              'object': 'model',
              'owned_by': 'local',
              'name': model.name,
              'type': model.type.wireName,
              'runtime': model.runtime.wireName,
              'format': model.format.wireName,
              'loaded': model.loaded,
              'default': model.isDefault,
            })
        .toList();
    await _json(response, HttpStatus.ok, {'object': 'list', 'data': data});
  }

  Future<void> _capabilitiesEndpoint(HttpResponse response) async {
    final models = _models();
    bool available(ModelType type) => models.any((m) => m.type == type && m.loaded);
    await _json(response, HttpStatus.ok, {
      'server': 'eburon-hub',
      'protocols': ['http', 'sse', 'websocket'],
      'openai_compatible': true,
      'capabilities': {
        'chat': available(ModelType.llm),
        'completions': available(ModelType.llm),
        'transcriptions': available(ModelType.stt),
        'speech': available(ModelType.tts),
        'images': available(ModelType.image),
        'realtime_transcription': available(ModelType.stt),
        'realtime_speech': available(ModelType.tts),
      }
    });
  }

  Future<void> _chatEndpoint(
    HttpRequest request, {
    required bool legacyCompletion,
  }) async {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final stream = payload['stream'] as bool? ?? false;
    final modelId = payload['model']?.toString() ?? 'local-model';
    final messages = <Map<String, String>>[];
    String prompt = '';
    String? systemPrompt;

    if (legacyCompletion) {
      prompt = payload['prompt']?.toString() ?? '';
    } else {
      for (final raw in payload['messages'] as List<dynamic>? ?? const []) {
        if (raw is! Map) continue;
        final role = raw['role']?.toString() ?? 'user';
        final content = raw['content']?.toString() ?? '';
        if (role == 'system') {
          systemPrompt = content;
        } else {
          messages.add({'role': role, 'content': content});
          if (role == 'user') prompt = content;
        }
      }
    }

    final chat = _chat;
    if (chat == null) {
      await _notReady(request.response, 'llama.cpp adapter / loaded LLM');
      return;
    }

    final cancellation = CancellationToken();
    unawaited(request.response.done.whenComplete(cancellation.cancel));
    final tokenStream = chat(prompt, systemPrompt, messages, cancellation);
    final id = 'chatcmpl-local-${DateTime.now().microsecondsSinceEpoch}';
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (stream) {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers
        ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..set(HttpHeaders.connectionHeader, 'keep-alive');
      await for (final token in tokenStream) {
        if (cancellation.isCancelled) break;
        final event = {
          'id': id,
          'object': 'chat.completion.chunk',
          'created': created,
          'model': modelId,
          'choices': [
            {
              'index': 0,
              'delta': {'content': token},
              'finish_reason': null,
            }
          ],
        };
        request.response.write('data: ${jsonEncode(event)}\n\n');
        await request.response.flush();
      }
      request.response.write('data: [DONE]\n\n');
      await request.response.flush();
      await request.response.close();
      await cancellation.dispose();
      return;
    }

    final buffer = StringBuffer();
    await for (final token in tokenStream) {
      buffer.write(token);
    }
    await _json(request.response, HttpStatus.ok, {
      'id': id,
      'object': legacyCompletion ? 'text_completion' : 'chat.completion',
      'created': created,
      'model': modelId,
      'choices': [
        legacyCompletion
            ? {
                'index': 0,
                'text': buffer.toString(),
                'finish_reason': 'stop',
              }
            : {
                'index': 0,
                'message': {'role': 'assistant', 'content': buffer.toString()},
                'finish_reason': 'stop',
              }
      ],
      'usage': {
        'prompt_tokens': 0,
        'completion_tokens': 0,
        'total_tokens': 0,
      },
    });
    await cancellation.dispose();
  }

  Future<void> _realtimeSocket(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      await _json(request.response, HttpStatus.badRequest, {
        'error': {'message': 'WebSocket upgrade required'}
      });
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.add(jsonEncode({
      'type': 'error',
      'error': {
        'code': 'runtime_not_loaded',
        'message': 'Realtime native stream adapter is not linked yet.'
      }
    }));
    await socket.close();
  }

  Future<void> _notReady(HttpResponse response, String component) =>
      _json(response, HttpStatus.serviceUnavailable, {
        'error': {
          'message': '$component is not available',
          'type': 'runtime_unavailable',
        }
      });

  Future<void> _json(
    HttpResponse response,
    int status,
    Object value,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
    await response.close();
  }

  Future<void> dispose() async {
    await stop();
    await _activity.close();
  }
}

class ServerActivity {
  const ServerActivity(
    this.requestId,
    this.method,
    this.path,
    this.active, {
    this.duration,
  });

  final String requestId;
  final String method;
  final String path;
  final bool active;
  final Duration? duration;
}

class _RateBucket {
  _RateBucket(this.started, this.count);
  final DateTime started;
  int count;
}
