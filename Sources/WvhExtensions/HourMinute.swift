//
//  HourMinute.swift
//  OnTheDaily
//
//  Created by Gardner von Holt on 12/3/25.
//

import Foundation

public struct HourMinute: Codable, Comparable, Sendable, Equatable {
    public let hour: Int   // 0...23
    public let minute: Int // 0...59

    public init(_ hour: Int, _ minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(_ date: Date) {
        self.hour = Calendar.current.component(.hour, from: Date())
        self.minute = Calendar.current.component(.minute, from: Date())
    }

    public static func < (lhs: HourMinute, rhs: HourMinute) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    public static func > (lhs: HourMinute, rhs: HourMinute) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour > rhs.hour }
        return lhs.minute > rhs.minute
    }

    public static func == (lhs: HourMinute, rhs: HourMinute) -> Bool {
        return lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }

    public static func > (lhs: HourMinute, rhs: Date) -> Bool {
        let rhsHourMinute = HourMinute(Date.now)
        return lhs > rhsHourMinute
    }

    public static func < (lhs: HourMinute, rhs: Date) -> Bool {
        let rhsHourMinute = HourMinute(Date.now)
        return lhs < rhsHourMinute
    }

    public static func == (lhs: HourMinute, rhs: Date) -> Bool {
        let rhsHourMinute = HourMinute(Date.now)
        return lhs == rhsHourMinute
    }

    public func toString() -> String {
        return "\(self.hour):\(self.minute)"
    }
}
