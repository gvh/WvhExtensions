//
//  ReorderableDragRelocateDelegate.swift
//  Movey
//
//  Created by Gardner von Holt on 1/16/25.
//

import Foundation
import SwiftUI

struct ReorderableDragRelocateDelegate<Item: Reorderable>: DropDelegate {

    let item: Item
    var items: [Item]

    @Binding var active: Item?
    @Binding var hasChangedLocation: Bool

    var moveAction: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard item != active, let current = active else { return }
        guard let from = items.firstIndex(of: current) else { return }
        guard let to = items.firstIndex(of: item) else { return }
        hasChangedLocation = true
        if items[to] != current {
            moveAction(IndexSet(integer: from), to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        hasChangedLocation = false
        active = nil
        return true
    }
}
