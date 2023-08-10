//
//  UIResponderExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 12/1/21.
//  Copyright © 2021-2023 Gardner von Holt. All rights reserved.
//

#if canImport(UIKit)

import UIKit

@available(iOS 13.0, *)
public extension UIResponder {
    @available(iOS 13.0, *)
    @objc var scene: UIScene? {
        return nil
    }
}

@available(iOS 13.0, *)
public extension UIScene {
    @available(iOS 13.0, *)
    @objc override var scene: UIScene? {
        return self
    }
}

public extension UIView {
    @available(iOS 13.0, *)
    @objc override var scene: UIScene? {
        if let window = self.window {
            return window.windowScene
        } else {
            return self.next?.scene
        }
    }
}

public extension UIViewController {
    @available(iOS 13.0, *)
    @objc override var scene: UIScene? {
        // Try walking the responder chain
        @available(iOS 13.0, *)
        var res = self.next?.scene
        if res == nil {
            // That didn't work. Try asking my parent view controller
            res = self.parent?.scene
        }
        if res == nil {
            // That didn't work. Try asking my presenting view controller
            res = self.presentingViewController?.scene
        }

        return res
    }
}

#endif
