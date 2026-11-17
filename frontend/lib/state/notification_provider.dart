import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../core/api_client.dart';
import '../core/push_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';

/// Keeps the in-app notification centre and the FCM device token in sync.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._api, this._auth) {
    _wasSignedIn = _auth.isSignedIn;
    _auth.addListener(_handleAuthChanged);
    if (_auth.status != AuthStatus.loading) {
      _handleAuthChanged();
    }
  }

  final ApiClient _api;
  final AuthProvider _auth;
  bool _wasSignedIn = false;
  bool _disposed = false;
  Timer? _poll;
  bool _pushStarted = false;

  List<AppNotificationItem> _items = const [];
  int _unread = 0;
  bool _loading = false;
  String? _error;
  bool _pushConfigured = false;
  bool _pushDenied = false;

  List<AppNotificationItem> get items => _items;
  int get unread => _unread;
  bool get loading => _loading;
  String? get error => _error;
  bool get pushConfigured => _pushConfigured;
  bool get pushDenied => _pushDenied;
  bool get isSignedIn => _auth.isSignedIn;

  void _handleAuthChanged() {
    final signedIn = _auth.isSignedIn;
    if (signedIn && !_wasSignedIn) {
      _wasSignedIn = true;
      unawaited(load(silent: true));
      _startPolling();
      unawaited(_startPush());
    } else if (!signedIn && _wasSignedIn) {
      _wasSignedIn = false;
      _poll?.cancel();
      _items = const [];
      _unread = 0;
      _notify();
    } else if (signedIn) {
      _wasSignedIn = true;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_auth.isSignedIn) load(silent: true);
    });
  }

  Future<void> _startPush() async {
    if (_pushStarted && !PushService.instance.isDenied) return;
    _pushConfigured = PushService.instance.isConfigured;
    _pushDenied = PushService.instance.isDenied;
    _notify();
    if (!_pushConfigured) return;
    _pushStarted = true;
    await PushService.instance.start(
      registerToken: _registerToken,
      onMessage: _onForegroundMessage,
    );
    _pushDenied = PushService.instance.isDenied;
    _notify();
  }

  Future<void> enablePush() async {
    _pushConfigured = PushService.instance.isConfigured;
    if (!_pushConfigured) {
      _notify();
      return;
    }
    await PushService.instance.requestPermissionAgain(
      registerToken: _registerToken,
      onMessage: _onForegroundMessage,
    );
    _pushDenied = PushService.instance.isDenied;
    _notify();
  }

  Future<void> _registerToken(String token) async {
    final platform = kIsWeb ? 'WEB' : defaultTargetPlatform.name.toUpperCase();
    await _api.post('/notifications/devices', body: {
      'token': token,
      'platform': platform,
    });
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Purana Bazaar';
    final body = message.notification?.body ?? 'You have a new update.';
    appMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'View', onPressed: load),
      ),
    );
    unawaited(load(silent: true));
  }

  Future<void> load({bool silent = false}) async {
    if (!_auth.isSignedIn) return;
    if (!silent && !_loading) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final results = await Future.wait([
        _api.get('/notifications'),
        _api.get('/notifications/unread-count'),
      ]);
      final list = results[0] as List<dynamic>;
      final count = results[1] as Map<String, dynamic>;
      _items = list
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationItem.fromJson)
          .toList();
      _unread = count['count'] is num ? (count['count'] as num).toInt() : 0;
      _pushConfigured = count['pushEnabled'] == true;
      _error = null;
    } on ApiException catch (error) {
      if (!silent) _error = error.message;
    } catch (_) {
      if (!silent) _error = 'Could not load notifications.';
    } finally {
      if (!silent) _loading = false;
      _notify();
    }
  }

  Future<void> markRead(AppNotificationItem item) async {
    if (item.read) return;
    try {
      await _api.put('/notifications/${item.id}/read');
      _items = [
        for (final existing in _items)
          if (existing.id == item.id)
            existing.copyWith(read: true)
          else
            existing,
      ];
      _unread = _unread > 0 ? _unread - 1 : 0;
      _notify();
    } on ApiException catch (error) {
      _error = error.message;
      _notify();
    }
  }

  Future<void> markAllRead() async {
    if (_unread == 0) return;
    try {
      await _api.put('/notifications/read-all');
      _items = [for (final item in _items) item.copyWith(read: true)];
      _unread = 0;
      _notify();
    } on ApiException catch (error) {
      _error = error.message;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _auth.removeListener(_handleAuthChanged);
    super.dispose();
  }
}
