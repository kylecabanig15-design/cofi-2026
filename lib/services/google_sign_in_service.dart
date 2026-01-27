import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign In...');

      // First check if user is already signed in
      try {
        final isSignedIn = await _googleSignIn.isSignedIn();
        if (isSignedIn) {
          // Force disconnect to allow picking a new account or refreshing permissions
          await _googleSignIn.disconnect();
        }
      } catch (e) {
        print('Disconnect error during sign in (ignoring): $e');
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('User cancelled');
        return null;
      }

      print('Got Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print('Signed in successfully');

      await _createOrUpdateUser(userCredential.user!);

      return userCredential;
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  static Future<void> _createOrUpdateUser(User user) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          // photoUrl intentionally omitted - users will see CoFi logo by default
          'commitment': false,
          'address': '',
          'bookmarks': [],
          'visited': [],
          'reviews': [],
          'emailVerified': user.emailVerified,
          'isAdmin': false, // NEW: Explicitly initialize
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('User document created');
      } else {
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
        });
        print('User document updated');
      }
    } catch (e) {
      print('Firestore error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Ensure we disconnect from Google to clear the cache and allow account selection next time
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }
      await _googleSignIn.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }
  static Future<void> reAuthenticateWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.currentUser?.reauthenticateWithCredential(credential);
    } catch (e) {
      print('Re-authentication error: $e');
      rethrow;
    }
  }
}
