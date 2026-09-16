import '../../calendar_repository.dart';

/// Contract for occurrence command execution.
abstract class OccurrenceCommandHandler<C extends OccurrenceCommand, R> {
  Future<R> handle(C command);
}

/// Dispatch registry for occurrence commands.
class OccurrenceCommandDispatcher {
  final Map<Type, _TypeErasedHandler> _handlers = {};

  void register<C extends OccurrenceCommand, R>(
    OccurrenceCommandHandler<C, R> handler,
  ) {
    _handlers[C] = _TypeErasedHandler<C, R>(handler);
  }

  Future<R> dispatch<C extends OccurrenceCommand, R>(C command) {
    final handler = _handlers[command.runtimeType];
    if (handler == null) {
      throw UnsupportedError(
        'No handler registered for command type ${command.runtimeType}.',
      );
    }
    return handler.handle(command).then((res) => res as R);
  }
}

class _TypeErasedHandler<C extends OccurrenceCommand, R> {
  final OccurrenceCommandHandler<C, R> _handler;

  const _TypeErasedHandler(this._handler);

  Future<dynamic> handle(OccurrenceCommand command) =>
      _handler.handle(command as C);
}
