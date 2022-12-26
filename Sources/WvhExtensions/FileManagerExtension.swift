//
//  FileManagerExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 12/12/19.
//  Copyright © 2019-2023 Gardner von Holt. All rights reserved.
//

import Foundation

public extension FileManager {
    class func documentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
}
