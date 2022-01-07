//
//  UILabelExtension.swift
//  mediatransport
//
//  Created by Gardner von Holt on 3/8/19.
//  Copyright © 2019 Gardner von Holt. All rights reserved.
//

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
