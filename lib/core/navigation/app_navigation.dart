import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The canonical destination for the app's Training bottom-navigation tab.
const trainingTabRoute = '/training';

/// Hands off a primary workout action to Training without stacking another
/// copy of the app shell above the current tab.
void goToTrainingTab(BuildContext context) {
  context.go(trainingTabRoute);
}
