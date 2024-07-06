//
//  ColorExtension.swift
//  
//
//  Created by Gardner von Holt on 2/8/23.
//

import SwiftUI

extension Color : @retroactive Comparable {
    public static func < (lhs: Color, rhs: Color) -> Bool {
        let lhsInt: Int = lhs.intForColor()
        let rhsInt: Int = rhs.intForColor()
        return lhsInt < rhsInt
    }

    private func intForColor() -> Int {
        var sortOrder: Int
        switch self {
        case .gray:
            sortOrder = 1
        case .blue:
            sortOrder = 2
        case .green:
            sortOrder = 3
        case .yellow:
            sortOrder = 4
        case .red:
            sortOrder = 5
        default:
            sortOrder = 6
        }
        return sortOrder
    }

}
