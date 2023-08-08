//
//  IntExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 2016/Nov/28.
//  Copyright © 2016-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension Int {

    private static var ordinalFormatter: NumberFormatter = {
        let foramtter = NumberFormatter()
        foramtter.numberStyle = .ordinal
        return foramtter
    }()

    private static var commaFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var commaRepresentation: String {
        return Int.commaFormatter.string(from: NSNumber(value: self)) ?? ""
    }

    var ordinalRepresentation: String {
        return Int.ordinalFormatter.string(from: NSNumber(value: self)) ?? ""
    }

}
