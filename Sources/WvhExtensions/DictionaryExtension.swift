//
//  DictionaryExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/7/19.
//  Copyright © 2019-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension Dictionary where Value: Comparable {
    var sortedByValue: [(Key, Value)] { return Array(self).sorted { $0.1 < $1.1 } }
}

public extension Dictionary where Key: Comparable {
    var sortedByKey: [(Key, Value)] { return Array(self).sorted { $0.0 < $1.0 } }
}
