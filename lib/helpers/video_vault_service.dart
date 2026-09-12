import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoVaultService {
  static final instance = VideoVaultService();
  VideoVaultService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.rocwei.password/video_vault') {
    if (!supported && channel == null) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return;
      final event = Map<String, dynamic>.from(call.arguments as Map);
      if (event['type'] == 'locked') {
        _session = null;
        _epoch++;
      }
      _events.add(event);
    });
  }

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final MethodChannel _channel;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;
  String? _session;
  int _epoch = 0;

  Future<void> open() async {
    if (!supported) throw PlatformException(code: 'unsupported');
    final epoch = _epoch;
    final token = await _channel.invokeMethod<String>('open');
    if (epoch != _epoch || token == null) {
      throw PlatformException(code: 'locked');
    }
    _session = token;
  }

  Future<List<Map<String, dynamic>>> list() async {
    final records = await _invoke<List<dynamic>>('list');
    return (records ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> importVideo(String source) =>
      _invoke('import', {'source': source});
  Future<void> play(String id, String done) =>
      _invoke('play', {'id': id, 'done': done});
  Future<void> delete(String id) => _invoke('delete', {'id': id});
  Future<void> cancel() => _invoke('cancel');

  Future<T?> _invoke<T>(String method, [Map<String, Object?> args = const {}]) {
    final session = _session;
    if (session == null) throw PlatformException(code: 'locked');
    return _channel.invokeMethod<T>(method, {...args, 'session': session});
  }

  Future<void> close() async {
    _session = null;
    _epoch++;
    if (!supported) return;
    await _channel.invokeMethod<void>('close');
  }

  void invalidate() {
    unawaited(
      close().catchError((Object _) {
        _events.add({'type': 'cleanupFailed'});
      }),
    );
  }

  Future<void> deleteAll() async {
    _session = null;
    _epoch++;
    if (supported) await _channel.invokeMethod<void>('deleteAll');
  }
}
