import ActivityKit
import Foundation

@available(iOS 16.1, *)
public final class RestTimerLiveActivityManager {
    public static let shared = RestTimerLiveActivityManager()
    private init() {}

    public var areActivitiesEnabled: Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    @discardableResult
    public func start(
        periodId: String,
        exerciseName: String,
        targetSeconds: Int,
        restEndDate: Date
    ) -> Bool {
        guard areActivitiesEnabled else { return false }

        // Enforce single-timer invariant: immediately dismiss any active timer
        endAllActivities(immediate: true)

        let attributes = RestTimerAttributes(workoutTitle: "Workout Rest")
        let initialState = RestTimerAttributes.ContentState(
            exerciseName: exerciseName,
            targetSeconds: targetSeconds,
            restEndDate: restEndDate,
            periodId: periodId,
            isCompleted: false
        )

        do {
            let content = ActivityContent(
                state: initialState,
                staleDate: restEndDate.addingTimeInterval(30)
            )
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            return true
        } catch {
            print("[RestTimerLiveActivityManager] Activity.request failed: \(error)")
            return false
        }
    }

    public func update(
        periodId: String,
        exerciseName: String,
        targetSeconds: Int,
        restEndDate: Date,
        isCompleted: Bool = false
    ) {
        guard areActivitiesEnabled else { return }

        let updatedState = RestTimerAttributes.ContentState(
            exerciseName: exerciseName,
            targetSeconds: targetSeconds,
            restEndDate: restEndDate,
            periodId: periodId,
            isCompleted: isCompleted
        )
        let content = ActivityContent(
            state: updatedState,
            staleDate: restEndDate.addingTimeInterval(30)
        )

        Task {
            for activity in Activity<RestTimerAttributes>.activities {
                if activity.content.state.periodId == periodId || activity.content.state.periodId.isEmpty {
                    await activity.update(content)
                }
            }
        }
    }

    public func end(periodId: String? = nil, immediate: Bool = true) {
        guard areActivitiesEnabled else { return }

        Task {
            for activity in Activity<RestTimerAttributes>.activities {
                if periodId == nil || activity.content.state.periodId == periodId {
                    if immediate {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    } else {
                        // Expiry completion: update to completed state and dismiss after short window per HIG
                        let currentState = activity.content.state
                        let completedState = RestTimerAttributes.ContentState(
                            exerciseName: currentState.exerciseName,
                            targetSeconds: currentState.targetSeconds,
                            restEndDate: currentState.restEndDate,
                            periodId: currentState.periodId,
                            isCompleted: true
                        )
                        let finalContent = ActivityContent(state: completedState, staleDate: nil)
                        await activity.update(finalContent)
                        await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(20)))
                    }
                }
            }
        }
    }

    public func endAllActivities(immediate: Bool = true) {
        guard areActivitiesEnabled else { return }

        Task {
            for activity in Activity<RestTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: immediate ? .immediate : .default)
            }
        }
    }
}
