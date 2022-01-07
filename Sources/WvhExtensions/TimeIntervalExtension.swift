//
//  TimeIntervalExtension.swift
//  TimeIntervalExtension
//
//  Created by Gardner von Holt on 8/6/21.
//

import Foundation

public extension TimeInterval {

    func stringFromTimeInterval(durationFormat: DurationFormat) -> String {

        var time = NSInteger(self)
        time = abs(time)
        let minutes = (time / 60) % 60
        let hours = (time / 3600)

        switch durationFormat {
        case .colon:
            return String(format: "%d:%02d", hours, minutes)

        case .colonzero:
            return String(format: "%02d:%02d", hours, minutes)

        case .hm:
            return hours > 0 ? String(format: "%dh %dm", hours, minutes) : String(format: "%dm", minutes)

        case .hmzero:
            return hours > 0 ? String(format: "%dh %02dm", hours, minutes) : String(format: "%dm", minutes)

        case .numberOnly:
            return String(format: "%", minutes)

        case .text:
            return hours > 0 ? String(format: "%d hours and %d minutes", hours, minutes) : String(format: "%d minutes", minutes)

        case .none:
            return ""
        }

    }
}
