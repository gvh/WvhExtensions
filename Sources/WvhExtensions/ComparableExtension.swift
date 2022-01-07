//
//  ComparableExtension.swift
//  ComparableExtension
//
//  Created by Gardner von Holt on 8/20/21.
//

import Foundation

public extension Comparable {

    func clamped(to range: ClosedRange<Self>) -> Self {

        if self > range.upperBound {
            return range.upperBound
        } else if self < range.lowerBound {
            return range.lowerBound
        } else {
            return self
        }
    }
}
