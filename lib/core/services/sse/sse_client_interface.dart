import 'dart:async';

abstract class SseClient {
  void connect(String url, {Map<String, String>? headers});
  void close();
  Stream<String> get messageStream;
}
