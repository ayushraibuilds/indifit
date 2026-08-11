import 'package:flutter/material.dart';

/// Quiet, compact feedback for ordinary successful actions.
SnackBar indiFitSuccessSnackBar(String message) =>
    SnackBar(behavior: SnackBarBehavior.floating, content: Text(message));
