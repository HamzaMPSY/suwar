import 'package:flutter/material.dart';
import '../../core/app_state.dart';

Future<void> finishOnboarding(BuildContext context, AppState app) async {
  await app.completeOnboarding();
  if (!context.mounted) return;
  if (app.storageError != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(app.storageError!)));
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
}
