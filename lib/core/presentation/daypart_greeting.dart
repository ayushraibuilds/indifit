/// Returns the consumer-facing greeting for a local wall-clock time.
///
/// The boundaries are deliberately explicit so the same copy is used by
/// Today and the legacy dashboard header:
/// morning 05:00–11:59, afternoon 12:00–16:59, evening 17:00–21:59, and a
/// neutral greeting overnight.
String daypartGreeting(DateTime localNow) {
  final hour = localNow.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 22) return 'Good evening';
  return 'Hi';
}

String daypartSubtitle(DateTime localNow) =>
    switch (daypartGreeting(localNow)) {
      'Good morning' => "Let's fuel your day and crush goals!",
      'Good afternoon' => 'Keep the momentum going!',
      'Good evening' => 'Great job today! Stay consistent.',
      _ => 'Ready when you are.',
    };
