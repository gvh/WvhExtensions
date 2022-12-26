//
//  UIImageExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 11/7/19.
//  Copyright © 2019-2023 Gardner von Holt. All rights reserved.
//

import UIKit
import CoreImage

@available(iOS 13.0, *)
public extension UIImage {

    func blur(amount: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: self) else {
            return nil
        }

        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter?.setValue(amount, forKey: kCIInputRadiusKey)

        guard let outputImage = blurFilter?.outputImage else {
            return nil
        }

        return UIImage(ciImage: outputImage)
    }

    func scaled(with scale: CGFloat) -> UIImage? {
        // size has to be integer, otherwise it could get white lines
        let size = CGSize(width: floor(self.size.width * scale), height: floor(self.size.height * scale))
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func resizeImage(newSize: CGSize) -> UIImage? {
        let oldSize = self.size

        let widthRatio = newSize.width / oldSize.width
        let heightRatio = newSize.height / oldSize.height

        let newRatio = min(widthRatio, heightRatio)

        return scaled(with: newRatio)

    }

    func resizeImage(_ dimension: CGFloat) -> UIImage {
        return self.resizeImage(dimension, opaque: true, contentMode: .scaleAspectFit)
    }

    @available(iOS 13.0, *)
    func resizeImage(_ dimension: CGFloat, opaque: Bool, contentMode: UIView.ContentMode = .scaleAspectFit) -> UIImage {
        var width: CGFloat
        var height: CGFloat
        var newImage: UIImage

        let size = self.size
        let aspectRatio =  size.width/size.height

        switch contentMode {
        case .scaleAspectFit:
            if aspectRatio > 1 {                            // Landscape image
                width = dimension
                height = dimension / aspectRatio
            } else {                                        // Portrait image
                height = dimension
                width = dimension * aspectRatio
            }

        default:
            fatalError("UIIMage.resizeToFit(): FATAL: Unimplemented ContentMode")
        }

        let renderFormat = UIGraphicsImageRendererFormat.preferred()
        renderFormat.opaque = opaque
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: renderFormat)
        newImage = renderer.image { ( _ ) in
            self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return newImage
    }

    func save(fileName: String) -> Bool {
        let urlString = URL(string: fileName)
        guard urlString != nil else { return false }
        return saveJPG(fullFileName: urlString!, compressionQuality: 1.0)
    }

    func saveJPG(fullFileName: URL, compressionQuality: CGFloat) -> Bool {
        if let data = self.jpegData(compressionQuality: compressionQuality) {
            do {
                try data.write(to: fullFileName)
                return true
            } catch {
                print(error.localizedDescription)
                return false
            }
        }
        print("save jpg error fell though")
        return false
    }

    func savePNG(fullFileName: URL) -> Bool {
        if let data = self.pngData() {
            do {
                try data.write(to: fullFileName)
                return true
            } catch {
                print(error.localizedDescription)
                return false
            }
        }
        print("save png error fell though")
        return false
    }

    private func getDocumentsDirectory() -> URL {
        // let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func writeText(drawText text: String, atPoint point: CGPoint) -> UIImage {

        let textColor = UIColor.white
        let textFont = UIFont(name: "Helvetica Bold", size: 12)!

        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(self.size, false, scale)

        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center

        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: paragraphStyle

        ] as [NSAttributedString.Key: Any]
        self.draw(in: CGRect(origin: CGPoint.zero, size: self.size))

        let rect = CGRect(origin: point, size: self.size)
        text.draw(in: rect, withAttributes: textFontAttributes)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }

    static func create(size: CGSize) -> UIImage {
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

    func bluredImage(radius: CGFloat) -> UIImage? {
        let radius: CGFloat = 20
        let context = CIContext(options: nil)
        let inputImage = CIImage(cgImage: self.cgImage!)
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue("\(radius)", forKey: kCIInputRadiusKey)
        let result = filter?.value(forKey: kCIOutputImageKey) as! CIImage
        let rect = CGRect(x: radius * 2, y: radius * 2, width: self.size.width - radius * 4, height: self.size.height - radius * 4)
        let cgImage = context.createCGImage(result, from: rect)!
        let returnImage = UIImage(cgImage: cgImage)
        return returnImage
    }

    enum Direction {
        case up
        case down
        case left
        case right
    }

    func imageSizeInPixel() -> CGSize {
        let heightInPoints = size.height
        let heightInPixels = heightInPoints * scale

        let widthInPoints = size.width
        let widthInPixels = widthInPoints * scale

        return CGSize(width: widthInPixels, height: heightInPixels)
    }

    func append(direction: Direction, image: UIImage) -> UIImage? {
        let selfImageSize = self.size
        let point = CGPoint(x: 0, y: selfImageSize.height)
        let newImage = append(atPoint: point, image: image)
        return newImage
    }

    func append(atPoint bottomImagePoint: CGPoint, image bottomImage: UIImage) -> UIImage? {
        let topImageSize = self.size
        let bottomImageSize = bottomImage.size
        let topImagePoint = CGPoint.zero
        let topImage = self

        let maxImageSizeX = max(topImageSize.width, bottomImagePoint.x + bottomImageSize.width)
        let maxImageSizeY = max(topImageSize.height, bottomImagePoint.y + bottomImageSize.height)
        let maxImageSize = CGSize(width: maxImageSizeX, height: maxImageSizeY)

        UIGraphicsBeginImageContextWithOptions(maxImageSize, false, 0.0)

        topImage.draw(in: CGRect(origin: topImagePoint, size: topImageSize))
        bottomImage.draw(in: CGRect(origin: bottomImagePoint, size: bottomImageSize))

        let mergedImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        return mergedImage
    }

    static func createSolid(size: CGSize) -> UIImage? {
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        context.setFillColor(UIColor.red.cgColor)
        let rect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.fill(rect)
        UIGraphicsEndImageContext()
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        return image
    }
}
