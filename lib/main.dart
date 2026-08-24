import 'package:cofi/utils/logger.dart';
import 'package:cofi/firebase_options.dart';
import 'package:cofi/root_auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cofi/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initializationError;
  
  try {
    debugLog('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugLog('Firebase initialized');

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024,
      );
    } catch (e) {
      debugLog('Firestore settings already initialized or recovered: $e');
    }

    await GetStorage.init();
    debugLog('GetStorage initialized');
    
    await NotificationService().init();
    debugLog('NotificationService initialized');
  } catch (e, stack) {
    debugLog('Error during initialization: $e');
    debugLog('Stack: $stack');
    initializationError = e.toString();
  }

  runApp(RootAuthGate(initializationError: initializationError));
}
