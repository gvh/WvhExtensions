//
//  UIViewControllerExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 12/19/21.
//  Copyright © 2021-2023 Gardner von Holt. All rights reserved.
//

#if canImport(UIKit)

import UIKit

public extension UIViewController {

    #if os(iOS)
    var deviceOrientation: UIDeviceOrientation {

        guard let window = view.window else { return .unknown }

        let fixedPoint = window.screen.coordinateSpace.convert(CGPoint.zero, to: window.screen.fixedCoordinateSpace)

        if fixedPoint.x == 0 {
            if fixedPoint.y == 0 { return .portrait }
            return .landscapeRight
        } else {
            if fixedPoint.y == 0 { return .landscapeLeft }
            return .portraitUpsideDown

        }
    }
    #endif

}

#endif
