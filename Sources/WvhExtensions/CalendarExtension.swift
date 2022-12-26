//
//  CalendarExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 10/15/22.
//  Copyright © 2022-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension Calendar {
    func endOfDay(for forDate: Date) -> Date {
        let oneDay = TimeInterval((24.0 * 60.0 * 60.0) - 1.0)
        let endDate = self.startOfDay(for: forDate).addingTimeInterval(oneDay)
        return endDate
    }
}
