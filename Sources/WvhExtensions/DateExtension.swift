//
//  DateExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 2015/Dec/14.
//  Copyright © 2015-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension Date {
    
    var zeroSeconds: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return calendar.date(from: dateComponents)!
    }
    
    var zeroMinutes: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        return calendar.date(from: dateComponents)!
    }
    
    var zeroHours: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        return calendar.date(from: dateComponents)!
    }
    
    func setHour(hour: Int) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        dateComponents.hour = hour
        dateComponents.minute = 0
        dateComponents.second = 0
        return calendar.date(from: dateComponents)!
    }
    
    func setMinute(minute: Int) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        dateComponents.minute = minute
        dateComponents.second = 0
        return calendar.date(from: dateComponents)!
    }

    func yyyymmddString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMdd")
        let str = dateFormatter.string(from: self)
        return str
    }

    func hmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("H:mm")
        let str = dateFormatter.string(from: self)
        return str
    }
    
    func hhmmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        let str = dateFormatter.string(from: self)
        return str
    }

    func hmampmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("H:mm a")
        let str = dateFormatter.string(from: self)
        return str
    }
    
    func hmsString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
        let str = dateFormatter.string(from: self)
        return str
    }
    
    func mString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func mmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func dString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func mdString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func dmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func dmmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func mmyyString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yy"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func yearString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }

    func dmyString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func mdyString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func dmyhmString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy HH:mm"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func dmyhmsString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy HH:mm:ss"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func dowString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE d MMM yyyy"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func yymmddString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func yymmddhhmmssString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    func ymdString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MMM d"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    func eeeeString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: self)
        return formattedDate
    }
    
    /// Returns the amount of hours from another date
    func hours(from date: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    
    /// Returns the amount of minutes from another date
    func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    
    func dateByAdding(days: Int) -> Date? {
        return Calendar.current.date(byAdding: .day, value: days, to: self)
    }
    
    func dateByAdding(hours: Int) -> Date? {
        return Calendar.current.date(byAdding: .hour, value: hours, to: self)
    }
    
    func dateByAdding(minutes: Int) -> Date? {
        return Calendar.current.date(byAdding: .minute, value: minutes, to: self)
    }
    
    func dateByAdding(seconds: Int) -> Date? {
        return Calendar.current.date(byAdding: .second, value: seconds, to: self)
    }
    
    func isAfter(_ other: Date) -> Bool {
        if self > other { return true } else { return false }
    }
    
    static func fromComponents(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        let userCalendar = Calendar.current
        var generatedDateComponents = DateComponents()
        generatedDateComponents.year = year
        generatedDateComponents.month = month
        generatedDateComponents.day = day
        generatedDateComponents.hour = hour
        generatedDateComponents.minute = minute
        generatedDateComponents.second = second
        let generatedDate = userCalendar.date(from: generatedDateComponents)!
        return generatedDate
    }
    
    func startOfMonth() -> Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month],
                                                                           from: Calendar.current.startOfDay(for: self)))!
    }
    
    func startOfYear() -> Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year],
                                                                           from: Calendar.current.startOfDay(for: self)))!
    }

    func sameDayAs(_ date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }

    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }

    func endOfDay() -> Date {
        return Calendar.current.endOfDay(for: self)
    }

    func endOfMonth() -> Date {
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth())!
    }
    
    func endOfYear() -> Date {
        return Calendar.current.date(byAdding: DateComponents(year: 1, day: -1), to: self.startOfYear())!
    }
    
    static func from(year: Int, month: Int, day: Int) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.timeZone = TimeZone.current
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        return calendar.date(from: dateComponents) ?? nil
    }
    
    func years(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.year], from: sinceDate, to: self).year
    }
    
    func months(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.month], from: sinceDate, to: self).month
    }
    
    func days(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.day], from: sinceDate, to: self).day
    }
    
    func hours(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.hour], from: sinceDate, to: self).hour
    }
    
    func minutes(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.minute], from: sinceDate, to: self).minute
    }
    
    func seconds(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.second], from: sinceDate, to: self).second
    }
    
    func clearTime() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: self)
        let tempDate = calendar.date(from: components)!
        return tempDate
    }
    


    static func yymmddParse(value: String?) -> Date? {
        guard value != nil else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale.current
        let tempDate = dateFormatter.date(from: value!)
        return tempDate
    }
    
    static func yymmddhhmmsszParse(value: String?) -> Date? {
        guard value != nil else { return nil }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions.insert(.withFractionalSeconds)
        let tempDate = dateFormatter.date(from: value!)
        return tempDate
    }
    
    static func makeDate(year: Int, month: Int = 1, day: Int = 1, hr: Int = 0, min: Int = 0, sec: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = DateComponents(timeZone: TimeZone.current, year: year, month: month, day: day, hour: hr, minute: min, second: sec)
        return calendar.date(from: components)!
    }
}
