# B01 — Training Programs and Scheduling

Status: Chartered
Base commit: `056f959`
Current schema: v14
Current backup format: v5
Platforms: Android and iOS

## Goal

Add the foundations and user-facing behavior required for structured workout programs and scheduling without breaking existing routines, workout history or backups.

## Included features

- Periodized programs and progression blocks
- Deload weeks
- Program calendar
- Workout rescheduling
- Skip and repeat behavior
- Travel-week mode
- Named gym-equipment profiles
- Exercise notes, setup preferences and personal reminders

## Required foundations

- Stable exercise identity
- Normalized equipment representation
- Program, template and scheduled-occurrence separation
- Local-date and timezone rules
- Backup and restore support for new user-owned records
- Compatibility with existing routines and completed sessions

## Excluded from this batch

- Automatic load and repetition targets
- Recovery-based programming
- Supersets and advanced set techniques
- Cardio and mobility session redesign
- Muscle-volume heat maps
- Nutrition features
- Readiness and adaptive coaching
- Large dashboard redesign

## Binding decisions

- Activated program versions are immutable.
- Editing an active program creates a new version.
- Scheduled occurrences remain mutable until the workout starts.
- Starting a workout creates an immutable execution snapshot.
- Rescheduling changes the date, not the program order.
- Missing or ambiguous exercise mappings must not be guessed.
- Core functionality must work offline.
- Existing user data must be preserved.
- Every new user-owned record must participate in backup and restore.

## Batch exit criteria

- Existing routines remain usable.
- Users can create or activate a versioned program.
- Programs support blocks, weeks and planned sessions.
- Scheduled workouts appear on a calendar.
- Users can reschedule, skip and repeat sessions.
- Travel-week behavior is explicit and tested.
- Equipment profiles affect exercise availability.
- Exercise-specific notes and setup preferences persist.
- Migration from schema v14 succeeds.
- Backup and restore cover all new records.
- Relevant tests, analysis and release builds pass.
