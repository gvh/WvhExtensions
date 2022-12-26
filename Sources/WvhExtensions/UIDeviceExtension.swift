//
//  UIDeviceExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/21/21.
//  Copyright © 2021-2023 Gardner von Holt. All rights reserved.
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
