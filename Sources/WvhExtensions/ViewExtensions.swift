//
//  ViewExtensions.swift
//  Movey
//
//  Created by Gardner von Holt on 1/11/23.
//

import Foundation
import SwiftUI

extension View {
    func dataController(_ value: DataController) -> some View {
        environment(\.dataController, value)
    }
}
