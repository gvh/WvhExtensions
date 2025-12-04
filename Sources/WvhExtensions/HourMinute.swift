//
//  HourMinute.swift
//  OnTheDaily
//
//  Created by Gardner von Holt on 12/3/25.
//

import Foundation

public class HourMinute: Codable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

extension HourMinute : Comparable {
    public static func < (lhs: HourMinute, rhs: HourMinute) -> Bool {
        return lhs.hour < rhs.hour || (lhs.hour == rhs.hour && lhs.minute < rhs.minute)
    }
    
    public static func == (lhs: HourMinute, rhs: HourMinute) -> Bool {
        return lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }
}
