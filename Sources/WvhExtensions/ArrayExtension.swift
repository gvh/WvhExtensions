//
//  ArrayExtension.swift
//  mediatransport
//
//  Created by Gardner von Holt on 8/7/19.
//  Copyright © 2019 Gardner von Holt. All rights reserved.
//

import Foundation

public extension Array where Element: Hashable {
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
