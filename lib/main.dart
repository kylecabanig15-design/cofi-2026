import 'package:cofi/firebase_options.dart';
import 'package:cofi/root_auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initializationError;
  
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized');

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024,
    );

    await GetStorage.init();
    print('GetStorage initialized');
  } catch (e, stack) {
    print('Error during initialization: $e');
    print('Stack: $stack');
    initializationError = e.toString();
  }

  runApp(RootAuthGate(initializationError: initializationError));
}
