//
//  UIViewControllerExtension.swift
//  StreamerSess
//
//  Created by Gardner von Holt on 12/19/21.
//

import UIKit

public extension UIViewController {

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

}
