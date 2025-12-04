//
//  DataExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 2017/Feb/19.
//  Copyright © 2017-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public enum RawImageType: Int {
    case jpg  = 0
    case png = 1
    case gif = 2
    case tiff = 3
    case unknown = 4
}

public extension Data {

    var imageFormat: RawImageType {
        let array = [UInt8](self)
        let ext: RawImageType

        switch array[0] {
        case 0xFF:
            ext = .jpg
        case 0x89:
            ext = .png
        case 0x47:
            ext = .gif
        case 0x49, 0x4D :
            ext = .tiff
        default:
            ext = .unknown
        }
        return ext
    }

    /// Append string to Data
    ///
    /// Rather than littering my code with calls to `data(using: .utf8)` to convert `String` values to `Data`, this wraps it in a nice convenient little extension to Data. This defaults to converting using UTF-8.
    ///
    /// - parameter string:       The string to be added to the `Data`.

    mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }

}
