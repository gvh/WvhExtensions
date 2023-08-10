//
//  UIDeviceExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/21/21.
//  Copyright © 2021-2023 Gardner von Holt. All rights reserved.
//
#if os(tvOS) || os(iOS)
import UIKit
#endif

public extension UIDevice {
    static var isIPad: Bool {
        #if os(tvOS) || os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    static var isIPhone: Bool {
#if os(tvOS) || os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }
}
