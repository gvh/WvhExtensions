//
//  ArrayExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/7/19.
//  Copyright © 2019-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension Array where Element: Hashable {
    func diff(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }

    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }

    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}
