//
//  ComparableExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/20/21.
//  Copyright © 2021-2023 Gardner von Holt. All rights reserved.
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
