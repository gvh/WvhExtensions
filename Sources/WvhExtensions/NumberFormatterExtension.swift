//
//  NumberFormatterExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 12/25/22.
//  Copyright © 2022-2023 Gardner von Holt. All rights reserved.
//

import Foundation

extension NumberFormatter {
    public func string(from number: Decimal) -> String? {
        return string(from: number as NSDecimalNumber)
    }
}
