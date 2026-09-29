// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'sse_client_interface.dart';

class PlatformSseClient implements SseClient {
  html.EventSource? _eventSource;
  final _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get messageStream => _controller.stream;

  @override
  void connect(String url, {Map<String, String>? headers}) {
    close();
    try {
      _eventSource = html.EventSource(url);
      _eventSource?.onMessage.listen((html.MessageEvent event) {
        if (event.data != null) {
          _controller.add(event.data.toString());
        }
      });
      _eventSource?.onError.listen((_) {
        // EventSource will auto-reconnect in browsers
      });
    } catch (e) {
      _controller.addError(e);
    }
  }

  @override
  void close() {
    _eventSource?.close();
    _eventSource = null;
  }
}

SseClient createPlatformSseClient() => PlatformSseClient();
