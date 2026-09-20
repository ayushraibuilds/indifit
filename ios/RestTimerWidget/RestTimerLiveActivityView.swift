import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
public struct RestTimerLiveActivityView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    private let emeraldColor = Color(red: 16/255, green: 185/255, blue: 129/255)
    private let amberColor = Color(red: 245/255, green: 158/255, blue: 11/255)

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Branding + Target duration badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundColor(emeraldColor)
                        .font(.system(size: 14, weight: .bold))
                    Text("IndiFit Rest")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("\(context.state.targetSeconds)s rest")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Main Content: Exercise details + Live Countdown Chronometer
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if context.state.isCompleted {
                        Text("Rest Complete! 💪")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(emeraldColor)
                        Text(context.state.exerciseName.isEmpty ? "Ready for next set" : "Next: \(context.state.exerciseName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(context.state.exerciseName.isEmpty ? "Resting between sets" : "Next: \(context.state.exerciseName)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("Tap to open workout")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if context.state.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(emeraldColor)
                } else {
                    Text(timerInterval: Date()...context.state.restEndDate, pauseTime: nil, countsDown: true)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(amberColor)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.85))
    }
}

@available(iOS 16.1, *)
public struct RestTimerActivityWidget: Widget {
    private let emeraldColor = Color(red: 16/255, green: 185/255, blue: 129/255)
    private let amberColor = Color(red: 245/255, green: 158/255, blue: 11/255)

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(emeraldColor)
                        Text("Rest")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.targetSeconds)s")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.isCompleted {
                        Text("Rest Complete 💪")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(emeraldColor)
                    } else {
                        Text(context.state.exerciseName.isEmpty ? "Resting" : "Next: \(context.state.exerciseName)")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if context.state.isCompleted {
                            Text("Ready for next set! Tap to resume.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        } else {
                            Text(timerInterval: Date()...context.state.restEndDate, countsDown: true)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(amberColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(context.state.isCompleted ? emeraldColor : amberColor)
            } compactTrailing: {
                if context.state.isCompleted {
                    Text("0:00")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(emeraldColor)
                } else {
                    Text(timerInterval: Date()...context.state.restEndDate, countsDown: true)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(amberColor)
                        .frame(minWidth: 36, alignment: .trailing)
                }
            } minimal: {
                Image(systemName: context.state.isCompleted ? "checkmark.circle.fill" : "timer")
                    .foregroundColor(context.state.isCompleted ? emeraldColor : amberColor)
            }
        }
    }
}
