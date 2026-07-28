enum AppFailureType {
  offlinePolicyBlocked,
  permissionDenied,
  validation,
  network,
  server,
  unsupportedPlatform,
  corruptedBackup,
  unknown,
}

class AppFailure {
  final AppFailureType type;
  final String message;
  final String? code;
  final String? technicalDetails;
  final String? actionLabel;
  final void Function()? onAction;

  const AppFailure({
    required this.type,
    required this.message,
    this.code,
    this.technicalDetails,
    this.actionLabel,
    this.onAction,
  });

  factory AppFailure.offlinePolicyBlocked({
    String? message,
    void Function()? onAction,
  }) {
    return AppFailure(
      type: AppFailureType.offlinePolicyBlocked,
      message: message ??
          'This feature requires an active connection, but "No Backend / Offline Mode" is enabled in settings.',
      actionLabel: 'Settings',
      onAction: onAction,
    );
  }

  factory AppFailure.permissionDenied({
    required String message,
    void Function()? onOpenSettings,
  }) {
    return AppFailure(
      type: AppFailureType.permissionDenied,
      message: message,
      actionLabel: 'Open Settings',
      onAction: onOpenSettings,
    );
  }

  factory AppFailure.validation({
    required String message,
    String? technicalDetails,
  }) {
    return AppFailure(
      type: AppFailureType.validation,
      message: message,
      technicalDetails: technicalDetails,
    );
  }

  factory AppFailure.network({
    required String message,
    void Function()? onRetry,
  }) {
    return AppFailure(
      type: AppFailureType.network,
      message: message,
      actionLabel: 'Retry Connection',
      onAction: onRetry,
    );
  }

  factory AppFailure.server({
    required String message,
    String? code,
    String? technicalDetails,
    void Function()? onRetry,
  }) {
    return AppFailure(
      type: AppFailureType.server,
      message: message,
      code: code,
      technicalDetails: technicalDetails,
      actionLabel: 'Retry Request',
      onAction: onRetry,
    );
  }

  factory AppFailure.unsupportedPlatform({
    required String message,
  }) {
    return AppFailure(
      type: AppFailureType.unsupportedPlatform,
      message: message,
    );
  }

  factory AppFailure.corruptedBackup({
    required String message,
    String? technicalDetails,
  }) {
    return AppFailure(
      type: AppFailureType.corruptedBackup,
      message: message,
      technicalDetails: technicalDetails,
    );
  }

  factory AppFailure.unknown({
    required String message,
    String? technicalDetails,
  }) {
    return AppFailure(
      type: AppFailureType.unknown,
      message: message,
      technicalDetails: technicalDetails,
    );
  }
}

sealed class Result<T> {
  const Result();

  factory Result.success(T data, {String? fallbackReason}) = Success<T>;
  factory Result.failure(AppFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  AppFailure? get failureOrNull => isFailure ? (this as Failure<T>).failure : null;
}

final class Success<T> extends Result<T> {
  final T data;
  final String? fallbackReason;

  const Success(this.data, {this.fallbackReason});

  bool get isFallback => fallbackReason != null && fallbackReason!.isNotEmpty;
}

final class Failure<T> extends Result<T> {
  final AppFailure failure;

  const Failure(this.failure);
}
