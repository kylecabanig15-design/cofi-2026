import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHandler {
  static String getFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return "We couldn't find an account with that email. Please check your spelling or sign up for a new account.";
        case 'wrong-password':
          return "The password you entered is incorrect. Please try again or reset your password if you've forgotten it.";
        case 'invalid-credential':
          return "The email or password provided is incorrect. Please double-check and try again.";
        case 'email-already-in-use':
          return "This email is already associated with an account. Try logging in instead or use a different email.";
        case 'invalid-email':
          return "That doesn't look like a valid email address. Please double-check it.";
        case 'weak-password':
          return "Your password is too short. Please use at least 6 characters to keep your account secure.";
        case 'network-request-failed':
          return "We're having trouble reaching our servers. Please check your internet connection and try again.";
        case 'too-many-requests':
          return "Too many failed attempts. Please wait a moment before trying again.";
        case 'requires-recent-login':
          return "For your security, please log in again before performing this action.";
        case 'operation-not-allowed':
          return "This sign-in method is currently disabled. Please contact support if you believe this is an error.";
        case 'user-disabled':
          return "This account has been disabled. Please contact support for assistance.";
        default:
          return error.message ?? "An unexpected authentication error occurred. Please try again later.";
      }
    } else if (error is TimeoutException) {
      return "The connection timed out. Please check your internet speed and try again.";
    } else if (error is FirebaseException) {
      return "We encountered a problem syncronizing your data. Please try again in a few moments.";
    }

    return "Something went wrong. Please try again or contact support if the problem persists.";
  }
}
