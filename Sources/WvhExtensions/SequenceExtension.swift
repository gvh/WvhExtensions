//
//  SequenceExtension.swift
//  MediaBrowser
//
//  Created by Gardner von Holt on 4/10/21.
//

import Foundation

public extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}
