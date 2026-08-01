import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_activity_session_repository.dart';
import '../../data/services/b02_activity_form_service.dart';
import 'b02_activity_controller.dart';

/// Manual typed-activity flow. Modality-specific validation is delegated to
/// the repository/model constructors, so this screen remains a form only.
class B02ActivityCreationScreen extends ConsumerStatefulWidget {
  final B02ActivityType initialType;
  final int? draftId;

  const B02ActivityCreationScreen({
    super.key,
    this.initialType = B02ActivityType.running,
    this.draftId,
  });

  @override
  ConsumerState<B02ActivityCreationScreen> createState() =>
      _B02ActivityCreationScreenState();
}

class _B02ActivityCreationScreenState
    extends ConsumerState<B02ActivityCreationScreen> {
  late B02ActivityType _type;
  final _name = TextEditingController();
  final _duration = TextEditingController();
  final _distance = TextEditingController();
  final _style = TextEditingController();
  final _intensity = TextEditingController();
  final _focus = TextEditingController();
  final _workSeconds = TextEditingController();
  final _recoverySeconds = TextEditingController();
  final _formService = const B02ActivityFormService();
  bool _interval = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _type =
        widget.initialType == B02ActivityType.strength ||
            widget.initialType == B02ActivityType.legacy
        ? B02ActivityType.running
        : widget.initialType;
    if (widget.draftId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(b02ActivityControllerProvider.notifier)
            .recover(widget.draftId!);
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _duration,
      _distance,
      _style,
      _intensity,
      _focus,
      _workSeconds,
      _recoverySeconds,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(b02ActivityControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Log activity')),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, B02ActivityControllerState state) {
    if (state.status == B02ActivityControllerStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == B02ActivityControllerStatus.failure ||
        state.status == B02ActivityControllerStatus.recovery) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'Activity recovery is needed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (state.draft != null)
                FilledButton(
                  onPressed: () => ref
                      .read(b02ActivityControllerProvider.notifier)
                      .recover(state.draft!.id),
                  child: const Text('Retry recovery'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Keep draft and go back'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.status == B02ActivityControllerStatus.completed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 52),
              const SizedBox(height: 12),
              const Text('Activity saved to typed history.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.draft != null) return _draftActions(context, state.draft!);
    return _form(context);
  }

  Widget _form(BuildContext context) {
    final cardio = _isCardio(_type);
    final mobility = _isMobility(_type);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Offline-first typed activity'),
          subtitle: Text(
            'Drafts are saved locally and can be recovered after restart.',
          ),
        ),
        const SizedBox(height: 8),
        Text('Activity type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in [
              B02ActivityType.running,
              B02ActivityType.cycling,
              B02ActivityType.walking,
              B02ActivityType.yoga,
              B02ActivityType.mobility,
            ])
              ChoiceChip(
                label: Text(_label(value)),
                selected: _type == value,
                onSelected: (_) => setState(() {
                  _type = value;
                  _validationError = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Session name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (seconds)',
            helperText: 'Required for every typed modality',
          ),
        ),
        if (cardio) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _distance,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Distance (metres, optional)',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Interval workout'),
            subtitle: const Text('Add ordered work/recovery segments.'),
            value: _interval,
            onChanged: (value) => setState(() => _interval = value),
          ),
          if (_interval)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _workSeconds,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Work seconds',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _recoverySeconds,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Recovery seconds',
                    ),
                  ),
                ),
              ],
            ),
        ],
        if (mobility) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _style,
            decoration: const InputDecoration(labelText: 'Style (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _intensity,
            decoration: const InputDecoration(
              labelText: 'Intensity (optional)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _focus,
            decoration: const InputDecoration(labelText: 'Focus (optional)'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yoga and mobility use duration plus optional style/focus/intensity. Distance and pace are not collected.',
          ),
        ],
        if (_validationError != null) ...[
          const SizedBox(height: 12),
          Text(
            _validationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start typed draft'),
          ),
        ),
      ],
    );
  }

  Widget _draftActions(BuildContext context, B02ActivityDraftRecord draft) {
    final state = draft.state;
    final detail = state.cardioDetail ?? state.mobilityDetail;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.restore_outlined),
          title: Text('Draft recovered'),
          subtitle: Text('Your typed fields are still local and editable.'),
        ),
        Card(
          child: ListTile(
            title: Text(state.routineName),
            subtitle: Text(
              '${_label(state.activityType)} · ${detail is B02CardioSessionDetail ? detail.durationSeconds : (detail as B02MobilitySessionDetail).durationSeconds}s',
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () =>
              ref.read(b02ActivityControllerProvider.notifier).completeDraft(),
          child: const Text('Save completed activity'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () =>
              ref.read(b02ActivityControllerProvider.notifier).saveDraft(state),
          child: const Text('Save partial draft'),
        ),
        TextButton(
          onPressed: () =>
              ref.read(b02ActivityControllerProvider.notifier).discard(),
          child: const Text('Discard draft'),
        ),
      ],
    );
  }

  Future<void> _start() async {
    final duration = int.tryParse(_duration.text.trim());
    if (_name.text.trim().isEmpty || duration == null || duration < 1) {
      setState(
        () => _validationError = 'Enter a session name and positive duration.',
      );
      return;
    }
    try {
      final details = _formService.build(
        activityType: _type,
        durationSeconds: duration,
        distanceMetres: int.tryParse(_distance.text.trim()),
        style: _style.text,
        intensity: _intensity.text,
        focusNote: _focus.text,
        isIntervalWorkout: _interval,
        workSeconds: int.tryParse(_workSeconds.text.trim()),
        recoverySeconds: int.tryParse(_recoverySeconds.text.trim()),
      );
      await ref
          .read(b02ActivityControllerProvider.notifier)
          .startManual(
            routineName: _name.text.trim(),
            activityType: _type,
            cardioDetail: details.cardioDetail,
            mobilityDetail: details.mobilityDetail,
          );
    } on B02ValidationException catch (error) {
      setState(() => _validationError = error.message);
    } catch (error) {
      setState(() => _validationError = error.toString());
    }
  }

  bool _isCardio(B02ActivityType type) => const {
    B02ActivityType.running,
    B02ActivityType.cycling,
    B02ActivityType.walking,
  }.contains(type);

  bool _isMobility(B02ActivityType type) =>
      const {B02ActivityType.yoga, B02ActivityType.mobility}.contains(type);

  String _label(B02ActivityType type) => switch (type) {
    B02ActivityType.running => 'Running',
    B02ActivityType.cycling => 'Cycling',
    B02ActivityType.walking => 'Walking',
    B02ActivityType.yoga => 'Yoga',
    B02ActivityType.mobility => 'Mobility',
    _ => type.dbValue,
  };
}

class B02ActivityHistoryCard extends StatelessWidget {
  final B02TypedActivityHistoryRecord record;

  const B02ActivityHistoryCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final detail = record.cardioDetail ?? record.mobilityDetail;
    final modality = detail is B02CardioSessionDetail
        ? '${detail.durationSeconds}s · ${detail.distanceMetres ?? 'distance unknown'} m'
        : detail is B02MobilitySessionDetail
        ? '${detail.durationSeconds}s · ${detail.style ?? 'style unknown'}'
        : '${record.durationSeconds}s';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(record.name),
        subtitle: Text(
          '${record.activityType.dbValue} · $modality · ${record.source.dbValue}',
        ),
      ),
    );
  }
}
