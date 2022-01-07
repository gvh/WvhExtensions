//
//  PHAssetExtension.swift
//  mediatransport
//
//  Created by Gardner von Holt on 2019/Jun/30.
//  Copyright © 2019 Gardner von Holt. All rights reserved.
//

import Foundation
import Photos

public extension PHAsset {

    func getURL(completionHandler: @escaping ((_ responseURL: URL?) -> Void)) {
        if self.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = { (_: PHAdjustmentData) -> Bool in
                return true
            }
            self.requestContentEditingInput(with: options,
                                            completionHandler: {(contentEditingInput: PHContentEditingInput?, _: [AnyHashable: Any]) -> Void in
                completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
            })
        } else if self.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: self, options: options,
                    resultHandler: {(asset: AVAsset?, _: AVAudioMix?, _: [AnyHashable: Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }
}
