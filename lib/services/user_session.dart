import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:cofi/models/user_model.dart';
import 'package:cofi/data/repositories/user_repository.dart';

/// Single source of truth for the signed-in user's profile document.
///
/// Replaces the pattern of subscribing to users/{uid} separately in every
/// screen (profile_tab alone had four concurrent listeners).
class UserSession extends ChangeNotifier {
  UserSession({UserRepository? repository, FirebaseAuth? auth})
      : _repository = repository ?? UserRepository(),
        _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final UserRepository _repository;
  final FirebaseAuth _auth;

  StreamSubscription<AppUser?>? _subscription;
  StreamSubscription<User?>? _authSub;

  // Guards against interleaved A→B auth transitions: a superseded run bails
  // out after every await so it never attaches its watcher or overwrites
  // the newer run's state.
  int _generation = 0;

  AppUser? _user;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isBusiness => _user?.isBusiness ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> _onAuthChanged(User? authUser) async {
    final generation = ++_generation;

    await _subscription?.cancel();
    if (generation != _generation) return; // Superseded mid-cancel.
    _subscription = null;
    _user = null;
    notifyListeners();

    if (authUser == null) return;

    AppUser? fetched;
    try {
      // Emit immediately from a one-shot read, then keep the stream attached
      // so role/profile edits propagate app-wide.
      fetched = await _repository.getUser(authUser.uid);
    } catch (e) {
      debugPrint('UserSession: failed to load user ${authUser.uid}: $e');
    }
    if (generation != _generation) return;
    _user = fetched;
    notifyListeners();

    _subscription = _repository.watchUser(authUser.uid).listen((user) {
      if (generation != _generation) return;
      _user = user;
      notifyListeners();
    }, onError: (e) {
      debugPrint('UserSession: watch error for ${authUser.uid}: $e');
      if (generation != _generation) return;
      // Retry once after a short delay so a transient failure doesn't leave
      // the session without a live watcher permanently.
      Timer(const Duration(seconds: 2), () async {
        if (generation != _generation) return;
        await _subscription?.cancel();
        if (generation != _generation) return;
        _subscription =
            _repository.watchUser(authUser.uid).listen((user) {
          if (generation != _generation) return;
          _user = user;
          notifyListeners();
        }, onError: (e) {
          debugPrint('UserSession: watch retry failed for '
              '${authUser.uid}: $e');
        });
      });
    });
  }

  /// Optimistic local update after a successful write.
  void applyLocalUpdate(AppUser updated) {
    _user = updated;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
