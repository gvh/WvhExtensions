//
//  UIDeviceExtension.swift
//  UIDeviceExtension
//
//  Created by Gardner von Holt on 8/21/21.
//

import UIKit

public extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}
