//
//  UIColorExtension.swift
//  UIColorExtension
//
//  Created by Gardner von Holt on 8/20/21.
//

import UIKit

public extension UIColor {
    /**
     Create a ligher color
     */
    func lighter(by percentage: CGFloat = 30.0) -> UIColor {
        return self.adjustBrightness(by: abs(percentage))
    }

    /**
     Create a darker color
     */
    func darker(by percentage: CGFloat = 30.0) -> UIColor {
        return self.adjustBrightness(by: -abs(percentage))
    }

    /**
     Try to increase brightness or decrease saturation
     */
    func adjustBrightness(by percentage: CGFloat = 30.0) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            if b < 1.0 {
                /**
                 Below is the new part, which makes the code work with black as well as colors
                 */
                let newB: CGFloat
                if b == 0.0 {
                    newB = max(min(b + percentage/100, 1.0), 0.0)
                } else {
                    newB = max(min(b + (percentage/100.0) * b, 1.0), 0.0)
                }
                return UIColor(hue: h, saturation: s, brightness: newB, alpha: a)
            } else {
                let newS: CGFloat = min(max(s - (percentage / 100.0) * s, 0.0), 1.0)
                return UIColor(hue: h, saturation: newS, brightness: b, alpha: a)
            }
        }
        return self
    }
}
