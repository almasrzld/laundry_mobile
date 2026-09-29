import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sse_client_interface.dart';

class PlatformSseClient implements SseClient {
  http.Client? _client;
  final _controller = StreamController<String>.broadcast();
  bool _isClosed = false;

  @override
  Stream<String> get messageStream => _controller.stream;

  @override
  void connect(String url, {Map<String, String>? headers}) async {
    close();
    _isClosed = false;
    _client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      if (headers != null) {
        request.headers.addAll(headers);
      }
      final streamedResponse = await _client!.send(request);

      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (_isClosed) return;
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isNotEmpty) {
              _controller.add(data);
            }
          }
        },
        onError: (err) {
          if (!_isClosed) {
            _controller.addError(err);
          }
        },
        onDone: () {
          // Closed by server
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (!_isClosed) {
        _controller.addError(e);
      }
    }
  }

  @override
  void close() {
    _isClosed = true;
    _client?.close();
    _client = null;
  }
}

SseClient createPlatformSseClient() => PlatformSseClient();
