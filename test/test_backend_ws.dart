import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main() async {
  print('Testing connection to wss://syncdub-translator-backend-1-hncr.onrender.com...');
  try {
    final uri = Uri.parse('wss://syncdub-translator-backend-1-hncr.onrender.com');
    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(const Duration(seconds: 15));
    print('WebSocket connected successfully!');

    final completer = Completer<void>();

    channel.stream.listen((event) {
      print('Received from WS: $event');
      if (!completer.isCompleted) completer.complete();
    }, onError: (err) {
      print('WS Error: $err');
      if (!completer.isCompleted) completer.completeError(err);
    }, onDone: () {
      print('WS closed');
      if (!completer.isCompleted) completer.complete();
    });

    // Send ping
    print('Sending ping action...');
    channel.sink.add(jsonEncode({'action': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch}));

    await completer.future.timeout(const Duration(seconds: 10));
    await channel.sink.close();
  } catch (e) {
    print('Exception during WS test: $e');
  }
}
