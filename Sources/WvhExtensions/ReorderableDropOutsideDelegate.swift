//
//  ReorderableDropOutsideDelegate.swift
//  Movey
//
//  Created by Gardner von Holt on 1/16/25.
//

import Foundation
import SwiftUI

struct ReorderableDropOutsideDelegate<Item: Reorderable>: DropDelegate {

    @Binding
    var active: Item?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        active = nil
        return true
    }
}

public extension View {

    func reorderableForEachContainer<Item: Reorderable>(
        active: Binding<Item?>
    ) -> some View {
        onDrop(of: [.text], delegate: ReorderableDropOutsideDelegate(active: active))
    }
}
