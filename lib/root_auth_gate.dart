import 'package:cofi/user_app.dart';
import 'package:flutter/material.dart';

class RootAuthGate extends StatelessWidget {
  final String? initializationError;
  const RootAuthGate({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    return UserApp(initializationError: initializationError);
  }
}
