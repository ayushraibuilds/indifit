import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var exerciseName: String
        public var targetSeconds: Int
        public var restEndDate: Date
        public var periodId: String
        public var isCompleted: Bool

        public init(
            exerciseName: String,
            targetSeconds: Int,
            restEndDate: Date,
            periodId: String,
            isCompleted: Bool = false
        ) {
            self.exerciseName = exerciseName
            self.targetSeconds = targetSeconds
            self.restEndDate = restEndDate
            self.periodId = periodId
            self.isCompleted = isCompleted
        }
    }

    public var workoutTitle: String

    public init(workoutTitle: String = "Workout Rest") {
        self.workoutTitle = workoutTitle
    }
}
