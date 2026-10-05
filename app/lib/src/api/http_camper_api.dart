import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../model.dart';
import 'camper_api.dart';

/// Talks to the Pi: REST for switching, a WebSocket for live state.
class HttpCamperApi implements CamperApi {
  HttpCamperApi(this.baseUri, {http.Client? client}) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;
  final _states = StreamController<CamperState>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  CamperState? _last;
  bool _connected = false;
  bool _started = false;
  bool _disposed = false;
  WebSocketChannel? _channel;
  Timer? _retry;

  @override
  Stream<CamperState> watch() async* {
    _start();
    if (_last != null) yield _last!;
    yield* _states.stream;
  }

  @override
  Stream<bool> get connection async* {
    _start();
    yield _connected;
    yield* _connection.stream;
  }

  void _start() {
    if (_started) return;
    _started = true;
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    final wsUri = baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/ws',
    );
    try {
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      await channel.ready;
      _setConnected(true);
      channel.stream.listen(
        (msg) => _emit(CamperState.fromJson(jsonDecode(msg as String) as Map<String, dynamic>)),
        onDone: _lost,
        onError: (_) => _lost(),
        cancelOnError: true,
      );
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    _setConnected(false);
    _channel = null;
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), _connect);
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_disposed) _connection.add(value);
  }

  void _emit(CamperState state) {
    _last = state;
    if (!_disposed) _states.add(state);
  }

  @override
  Future<CamperState> setSwitch(String id, bool on) async {
    final http.Response res;
    try {
      res = await _client
          .put(
            baseUri.replace(path: '/api/switches/${Uri.encodeComponent(id)}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'on': on}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      throw const ApiException('Keine Verbindung zur Steuereinheit.');
    }
    switch (res.statusCode) {
      case 200:
        final state = CamperState.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        _emit(state);
        return state;
      case 409:
        throw const SwitchLockedException();
      case 404:
        throw const ApiException('Diesen Schalter kennt die Steuereinheit nicht.');
      default:
        throw ApiException('Schalten fehlgeschlagen (${res.statusCode}).');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _channel?.sink.close();
    _client.close();
    _states.close();
    _connection.close();
  }
}
