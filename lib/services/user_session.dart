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
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  final UserRepository _repository;
  final FirebaseAuth _auth;

  StreamSubscription<AppUser?>? _subscription;

  AppUser? _user;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isBusiness => _user?.isBusiness ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> _onAuthChanged(User? authUser) async {
    await _subscription?.cancel();
    _subscription = null;
    _user = null;
    notifyListeners();

    if (authUser == null) return;

    // Emit immediately from a one-shot read, then keep the stream attached
    // so role/profile edits propagate app-wide.
    _user = await _repository.getUser(authUser.uid);
    notifyListeners();

    _subscription = _repository.watchUser(authUser.uid).listen((user) {
      _user = user;
      notifyListeners();
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
    super.dispose();
  }
}
