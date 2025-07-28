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

#if os(iOS) || os(macOS)
@available(iOS 16.0, macOS 13.0, *)
    func cacheDefeat() -> URL {
        let cacheDefeat = "\(Int(Date().timeIntervalSince1970) % 100000)"
        let url = self.appending(queryItems: [URLQueryItem(name: "z", value: cacheDefeat)])
        return url
    }
#endif
}
