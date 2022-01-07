//
//  UrlExtension.swift
//  mediatransport
//
//  Created by Gardner von Holt on 2018/Nov/18.
//  Copyright © 2018 Gardner von Holt. All rights reserved.
//

import Foundation
import AVKit

public extension URL {

    static func makeDocumentURL(fileName: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let tempDirectory = paths[0]
        let fullFileURL = tempDirectory.appendingPathComponent(fileName)
        return fullFileURL
    }

    func previewImageForLocalVideo(url: URL) -> UIImage? {
        let asset = AVAsset(url: self)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        var time = asset.duration
        time.value = min(time.value, 2)

        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch let error as NSError {
            print("Image generation failed with error \(error)")
            return nil
        }
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
