//
//  BidirectionalCollectionExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/12/19.
//  Copyright © 2019-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension BidirectionalCollection {
    subscript(safe offset: Int) -> Element? {
        guard !isEmpty, let i = index(startIndex, offsetBy: offset, limitedBy: index(before: endIndex)) else { return nil }
        return self[i]
    }
}
