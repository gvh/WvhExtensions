//
//  UrlExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 2018/Nov/18.
//  Copyright © 2018-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension URL {

    static func makeDocumentURL(fileName: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let tempDirectory = paths[0]
        let fullFileURL = tempDirectory.appendingPathComponent(fileName)
        return fullFileURL
    }

    func params() -> [String: String] {
        var dict = [String: String]()

        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    dict[item.name] = item.value! as String
                }
            }
            return dict
        } else {
            return [:]
        }
    }
}
