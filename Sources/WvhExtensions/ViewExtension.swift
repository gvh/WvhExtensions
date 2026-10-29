//
//  ViewExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 9/11/25.
//

import Foundation
import SwiftUI

// MARK: - System sensory feedback wrapper
public extension View {
    func sensoryImpact() -> some View {
        self.sensoryFeedback(.impact, trigger: UUID())
    }
}
