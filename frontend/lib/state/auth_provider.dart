import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/models.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._prefs) {
    _restore();
  }

  final SharedPreferences _prefs;
  final ApiClient _api = ApiClient.instance;

  AuthStatus _status = AuthStatus.loading;
  User? _user;
  String? _token;
  int? _shopId;
  String? _shopStatus;
  String? _startupError;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get token => _token;
  int? get shopId => _shopId;
  String? get shopStatus => _shopStatus;
  String? get startupError => _startupError;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  Future<void> _restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _token = _prefs.getString('auth.token');
    final storedRole = _prefs.getString('auth.role');
    if (_token == null || _token!.isEmpty || storedRole == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _api.token = _token;
    _user = User(
      id: _prefs.getInt('auth.userId') ?? 0,
      name: _prefs.getString('auth.name') ?? '',
      email: _prefs.getString('auth.email') ?? '',
      phone: _prefs.getString('auth.phone'),
      role: storedRole,
      active: true,
    );
    _shopId = _prefs.getInt('auth.shopId');
    _shopStatus = _prefs.getString('auth.shopStatus');
    _status = AuthStatus.signedIn;
    notifyListeners();

    try {
      final data = await _api.get('/auth/me') as Map<String, dynamic>;
      final account = AccountInfo.fromJson(data);
      _user = account.user;
      _shopId = account.shopId;
      _shopStatus = account.shopStatus;
      await _persist();
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _clearSession();
      }
    } catch (_) {
      // Keep the locally cached session when the network is temporarily unavailable.
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post('/auth/login', body: {
      'email': email.trim(),
      'password': password,
    }) as Map<String, dynamic>;
    await _acceptSession(AuthSession.fromJson(data));
  }

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      'password': password,
    }) as Map<String, dynamic>;
    await _acceptSession(AuthSession.fromJson(data));
  }

  Future<AuthSession> registerShopOwner(Map<String, dynamic> body) async {
    final data = await _api.post('/shop-owner/register', body: body)
        as Map<String, dynamic>;
    final session = AuthSession.fromJson(data);
    await _acceptSession(session);
    return session;
  }

  Future<void> updateProfile({String? name, String? phone}) async {
    final data = await _api.put('/customers/profile', body: {
      'name': ?name,
      'phone': ?phone,
    }) as Map<String, dynamic>;
    _user = User.fromJson(data);
    await _persist();
    notifyListeners();
  }

  Future<void> refreshAccount() async {
    if (_token == null) return;
    final data = await _api.get('/auth/me') as Map<String, dynamic>;
    final account = AccountInfo.fromJson(data);
    _user = account.user;
    _shopId = account.shopId;
    _shopStatus = account.shopStatus;
    await _persist();
    notifyListeners();
  }

  Future<void> _acceptSession(AuthSession session) async {
    _token = session.token;
    _api.token = session.token;
    _user = session.user;
    _shopId = session.shopId;
    _shopStatus = session.shopStatus;
    _status = AuthStatus.signedIn;
    _startupError = null;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final current = _user;
    if (_token == null || current == null) return;
    await _prefs.setString('auth.token', _token!);
    await _prefs.setInt('auth.userId', current.id);
    await _prefs.setString('auth.name', current.name);
    await _prefs.setString('auth.email', current.email);
    await _prefs.setString('auth.role', current.role);
    if (current.phone == null) {
      await _prefs.remove('auth.phone');
    } else {
      await _prefs.setString('auth.phone', current.phone!);
    }
    if (_shopId == null) {
      await _prefs.remove('auth.shopId');
    } else {
      await _prefs.setInt('auth.shopId', _shopId!);
    }
    if (_shopStatus == null) {
      await _prefs.remove('auth.shopStatus');
    } else {
      await _prefs.setString('auth.shopStatus', _shopStatus!);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Stateless logout: clearing the local token is sufficient.
    }
    await _clearSession();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _shopId = null;
    _shopStatus = null;
    _status = AuthStatus.signedOut;
    _api.token = null;
    for (final key in [
      'auth.token',
      'auth.userId',
      'auth.name',
      'auth.email',
      'auth.role',
      'auth.phone',
      'auth.shopId',
      'auth.shopStatus',
    ]) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }
}
