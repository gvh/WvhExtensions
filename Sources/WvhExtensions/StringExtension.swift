//
//  StringExtension.swift
//  mediatransport
//
//  Created by Gardner von Holt on 8/30/15.
//  Copyright © 2015 Gardner von Holt. All rights reserved.
//

import Foundation
import CommonCrypto

public extension String {

    func getUrlEncoded() -> String {
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "~-_."))
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)!
    }

    func removePunctuation() -> String {
        // All the characters to remove
        let punctuationCharacterSet = NSMutableCharacterSet.punctuationCharacters
        let arrayOfComponents = self.components(separatedBy: punctuationCharacterSet)
        let output = arrayOfComponents.joined(separator: " ")
        return output
    }
    
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }

    func beginsWith(_ s: String) -> Bool {
        return self.hasPrefix(s)
    }

    func beginsWith(_ c: Character) -> Bool {
        let s = String(c)
        return beginsWith(s)
    }

    func endsWith(_ s: String) -> Bool {
        return self.hasSuffix(s)
    }

    func endsWith(_ c: Character) -> Bool {
        let s = String(c)
        return endsWith(s)
    }

    func contains(_ find: String) -> Bool {
        return self.range(of: find) != nil
    }

    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    func localizedWithComment(comment: String) -> String {
        return NSLocalizedString(self, comment: comment)
    }

    static func localizedWithComment(_ id: String, value: String, comment: String) -> String {
        return NSLocalizedString(id, tableName: nil, bundle: Bundle.main, value: value, comment: comment)
    }

    func matchesForRegexInText(_ regex: String!) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error as NSError {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    func removeLeading(_ c: Character) -> String {
        var work = self
        while work.beginsWith(c) {
            work = String(work.dropFirst())
        }
        return work
    }

    func removeTrailing(_ c: Character) -> String {
        var work = self
        while work.endsWith(c) {
            work = String(work.dropLast())
        }
        return work
    }

    func count(of needle: Character) -> Int {
        return reduce(0) {
            $1 == needle ? $0 + 1 : $0
        }
    }

    func removeOneComponent() -> [String] {
        let workString = self.removeLeading("/").removeTrailing("/")
        let currentIndex = workString.firstIndexOf("/")
        if currentIndex != nil {
            let currentIndexBefore = workString.index(before: currentIndex!)
            let firstPathString = String(workString[...currentIndexBefore])
            let currentIndexAfter = workString.index(after: currentIndex!)
            let lastPathString = String(workString[currentIndexAfter...])
            return [firstPathString, lastPathString]
        } else {
            return [workString, ""]
        }
    }

    func lastPathComponent() -> String {
        var lastPath: String!
        var currentIndex = lastIndexOf("/")
        if currentIndex != nil {
            currentIndex = self.index(after: currentIndex!)
            let lastPathSubstring = self[currentIndex!...]
            lastPath = String(lastPathSubstring)
        } else {
            lastPath = self
        }
        return lastPath
    }

    func lastIndexOf(_ s: String) -> Index? {
        if let r: Range<Index> = self.range(of: s, options: .backwards) {
            return r.lowerBound
        }
        return nil
    }

    func firstIndexOf(_ s: String) -> Index? {
        if let r: Range<Index> = self.range(of: s) {
            return r.lowerBound
        }
        return nil
    }

    func indexOf(_ s: String) -> Index? {
        if let r: Range<Index> = self.range(of: s) {
            return r.lowerBound
        }
        return nil
    }

    func numberOfOccurencesOf(_ substring: String) -> Int {
        let components = self.components(separatedBy: substring)
        let countSlash = components.count - 1
        return countSlash
    }

    func withoutExtension() -> String {
        let lastDotIndex = lastIndexOf(".")
        if lastDotIndex != nil {
            let nameSubstring = self[..<lastDotIndex!]
            return String(nameSubstring)
        } else {
            return self
        }
    }

    var boolValue: Bool? {
        let lowercaseSelf = self.lowercased()

        switch lowercaseSelf {
        case "true", "yes", "t", "1":
            return true
        case "false", "no", "f", "0":
            return false
        default:
            return nil
        }
    }

    func removeComments() -> String {
        var response: String!
        if let index = self.range(of: "#")?.lowerBound {
            response = String(self.prefix(upTo: index)).trimmingCharacters(in: .whitespaces)
        } else {
            response = self.trimmingCharacters(in: .whitespaces)
        }
        return response
    }

    func isWord() -> Bool {
        if isEmpty { return false }
        if CharacterSet.letters.isSuperset(of: CharacterSet(charactersIn: self)) { return true }
        return false
    }

    var checkSum: String? {
        guard let stringData = self.data(using: String.Encoding.utf8) else { return nil }
        return digest(input: stringData as NSData).base64EncodedString(options: [])
    }

    private func digest(input: NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }

    func removeLeadingString(prefix: String?) -> String {
        guard prefix != nil else { return self }

        var searchPrefix: String = prefix!.trimmingCharacters(in: .whitespacesAndNewlines)
        searchPrefix = searchPrefix.starts(with: "/") ? String(searchPrefix.dropFirst(1)) : searchPrefix
        searchPrefix = searchPrefix.endsWith("/") ? String(searchPrefix.dropLast(1)) : searchPrefix
        let source = starts(with: "/") ? String(dropFirst()) : self
        if source.starts(with: searchPrefix) {
            var newString: String = source
            let length = searchPrefix.count
            newString = String(newString.dropFirst(length))
            return newString
        } else {
            return self
        }
    }

    func URLEncodedString() -> String? {
        let escapedString = self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        return escapedString
    }

    subscript(range: NSRange) -> Substring {
        if range.location == NSNotFound {
            return ""
        } else {
            let swiftRange = Range(range, in: self)!
            return self[swiftRange]
        }
    }

    /// Title-cased string is a string that has the first letter of each word capitalised (except for prepositions, articles and conjunctions)
    @available(iOS 11.0, *)
    func localizedTitleCasedString(linguistic: Bool) -> String {
        var newStr: String = ""

        // create linguistic tagger
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        let range = NSRange(location: 0, length: self.utf16.count)
        tagger.string = self

        // enumerate linguistic tags in string
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: []) { tag, tokenRange, _ in
            let word = self[tokenRange]

            guard let tag = tag else {
                newStr.append(contentsOf: word)
                return
            }

            // conjunctions, prepositions and articles should remain lowercased
            if linguistic == true && (tag == .conjunction || tag == .preposition || tag == .determiner) {
                newStr.append(contentsOf: word.localizedLowercase)
            } else {
                // any other words should be capitalized
                newStr.append(contentsOf: word.localizedCapitalized)
            }
        }
        return newStr
    }

    var isNotEmpty: Bool {
        return !self.isEmpty
    }

    var noPrefixName: String {
        if self.count > 2 && self[0] != " " && self[1] == " " {
            let startIndex = index(self.startIndex, offsetBy: 2)
            return String(self[startIndex...])
        } else {
            return self
        }
    }

    func indexInt(of char: Character) -> Int? {
        return firstIndex(of: char)?.utf16Offset(in: self)
    }

    func getDate(_ s: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date (from: self)
        return date
    }

}
