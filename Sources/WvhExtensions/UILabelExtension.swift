//
//  UILabelExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 3/8/19.
//  Copyright © 2019-2023 Gardner von Holt. All rights reserved.
//
#if canImport(UIKit)

import UIKit

public extension UILabel {

    var isTruncated: Bool {

        guard let labelText = text else {
            return false
        }

        let labelTextSize = (labelText as NSString).boundingRect(
            with: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font!],
            context: nil).size

        return labelTextSize.height > bounds.size.height
    }
}

#endif
