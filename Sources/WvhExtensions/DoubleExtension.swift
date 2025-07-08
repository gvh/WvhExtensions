//
//  File.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 7/8/25.
//

import Foundation

public extension Double {
    func displayString() -> String {
        if self - Double(Int(self)) < 0.10 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.1f", self)
        }
    }
}
