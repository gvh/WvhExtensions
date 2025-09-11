//
//  ViewExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 9/11/25.
//

import Foundation
import SwiftUI

// MARK: - System sensory feedback wrapper (no-op on older OS)
public extension View {
    @ViewBuilder
    func sensoryImpact() -> some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            self.sensoryFeedback(.impact, trigger: UUID())
        } else {
            self
        }
    }
}
