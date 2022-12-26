//
//  IntExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 2016/Nov/28.
//  Copyright © 2016-2023 Gardner von Holt. All rights reserved.
//

import Foundation

 let WORDSIZE = __WORDSIZE

public func arc4random<T: ExpressibleByIntegerLiteral>(_ type: T.Type) -> T {
    var r: T = 0
    arc4random_buf(&r, MemoryLayout<T>.size)
    return r
}

public extension UInt64 {

    static func random(lower: UInt64 = min, upper: UInt64 = max) -> UInt64 {
        var m: UInt64
        let u = upper - lower
        var r = arc4random(UInt64.self)

        if u > UInt64(Int64.max) {
            m = 1 + ~u
        } else {
            m = ((max - (u * 2)) + 1) % u
        }

        while r < m {
            r = arc4random(UInt64.self)
        }

        return (r % u) + lower
    }
}

public extension Int64 {
    static func random(lower: Int64 = min, upper: Int64 = max) -> Int64 {
        let (s, overflow) = upper.subtractingReportingOverflow(lower)
        let u = overflow ? UInt64.max - UInt64(~s) : UInt64(s)
        let r = UInt64.random(upper: u)
        if r > UInt64(Int64.max) {
            return Int64(r - (UInt64(~lower) + 1))
        } else {
            return Int64(r) + lower
        }
    }
}

public extension UInt32 {
    static func random(lower: UInt32 = min, upper: UInt32 = max) -> UInt32 {
        return arc4random_uniform(upper - lower) + lower
    }
}

public extension Int32 {
    static func random(lower: Int32 = min, upper: Int32 = max) -> Int32 {
        let r = arc4random_uniform(UInt32(Int64(upper) - Int64(lower)))
        return Int32(Int64(r) + Int64(lower))
    }
}

public extension UInt {
    static func random(lower: UInt = min, upper: UInt = max) -> UInt {
        switch WORDSIZE {
        case 32: return UInt(UInt32.random(lower: UInt32(lower), upper: UInt32(upper)))
        case 64: return UInt(UInt64.random(lower: UInt64(lower), upper: UInt64(upper)))
        default: return lower
        }
    }
}

public extension Int {
    static func random(lower: Int = min, upper: Int = max) -> Int {
        switch WORDSIZE {
        case 32: return Int(Int32.random(lower: Int32(lower), upper: Int32(upper)))
        case 64: return Int(Int64.random(lower: Int64(lower), upper: Int64(upper)))
        default: return lower
        }
    }
}

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
