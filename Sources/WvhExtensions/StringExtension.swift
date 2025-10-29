//
//  StringExtension.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 8/30/15.
//  Copyright © 2015-2023 Gardner von Holt. All rights reserved.
//

import Foundation
import CommonCrypto

public extension String {
    static let guidPred = NSPredicate(format: "SELF MATCHES %@", "((\\{|\\()?[0-9a-f]{8}-?([0-9a-f]{4}-?){3}[0-9a-f]{12}(\\}|\\))?)|(\\{(0x[0-9a-f]+,){3}\\{(0x[0-9a-f]+,){7}0x[0-9a-f]+\\}\\})")
    
    // Cached formatter for "yyyy-MM-dd" to avoid repeated creation cost.
    private static let yyyyMMddFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    func getUrlEncoded() -> String {
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "~-_."))
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? self
    }
    
    func removePunctuation() -> String {
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
    
    // Renamed to avoid overload ambiguity with String-based version.
    func beginsWithCharacter(_ c: Character) -> Bool {
        let s = String(c)
        return beginsWith(s)
    }
    
    func endsWith(_ s: String) -> Bool {
        return self.hasSuffix(s)
    }
    
    // Renamed to avoid overload ambiguity with String-based version.
    func endsWithCharacter(_ c: Character) -> Bool {
        let s = String(c)
        return endsWith(s)
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
            return results.compactMap { match in
                let r = match.range
                guard r.location != NSNotFound, r.location + r.length <= nsString.length else { return nil }
                return nsString.substring(with: r)
            }
        } catch let error as NSError {
            print("invalid regex: \(error)")
            return []
        }
    }
    
    func removeLeading(_ c: Character) -> String {
        var work = self
        while work.beginsWithCharacter(c) {
            work = String(work.dropFirst())
        }
        return work
    }
    
    func removeTrailing(_ c: Character) -> String {
        var work = self
        while work.endsWithCharacter(c) {
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
        guard let idx = workString.firstIndexOf("/") else {
            return [workString, ""]
        }
        let firstPathString = String(workString[..<idx])
        let after = workString.index(after: idx)
        let lastPathString = String(workString[after...])
        return [firstPathString, lastPathString]
    }
    
    func lastPathComponent() -> String {
        if let slashIndex = lastIndexOf("/") {
            let start = index(after: slashIndex)
            return String(self[start...])
        } else {
            return self
        }
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
        guard let lastDotIndex = lastIndexOf(".") else { return self }
        return String(self[..<lastDotIndex])
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
        if let index = self.range(of: "#")?.lowerBound {
            return String(self.prefix(upTo: index)).trimmingCharacters(in: .whitespaces)
        } else {
            return self.trimmingCharacters(in: .whitespaces)
        }
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
        guard var searchPrefix = prefix?.trimmingCharacters(in: .whitespacesAndNewlines), !searchPrefix.isEmpty else { return self }
        
        searchPrefix = searchPrefix.starts(with: "/") ? String(searchPrefix.dropFirst(1)) : searchPrefix
        searchPrefix = searchPrefix.endsWith("/") ? String(searchPrefix.dropLast(1)) : searchPrefix
        let source = starts(with: "/") ? String(dropFirst()) : self
        if source.starts(with: searchPrefix) {
            return String(source.dropFirst(searchPrefix.count))
        } else {
            return self
        }
    }
    
    func URLEncodedString() -> String? {
        let escapedString = self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        return escapedString
    }
    
    /// Title-cased string is a string that has the first letter of each word capitalised (except for prepositions, articles and conjunctions)
    func localizedTitleCasedString(linguistic: Bool) -> String {
        var newStr: String = ""
        
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        let range = NSRange(location: 0, length: self.utf16.count)
        tagger.string = self
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: []) { tag, tokenRange, _ in
            let word = self[tokenRange]
            
            guard let tag = tag else {
                newStr.append(contentsOf: word)
                return
            }
            
            if linguistic == true && (tag == .conjunction || tag == .preposition || tag == .determiner) {
                newStr.append(contentsOf: word.localizedLowercase)
            } else {
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
    
    // Consolidated date parsing using a cached formatter.
    func getDate() -> Date? {
        return String.yyyyMMddFormatter.date(from: self)
    }
    
    @available(*, deprecated, message: "Use getDate() instead. This method will be removed in a future release.")
    func yyyymmddToDate() -> Date? {
        return getDate()
    }
    
    func isGuid() -> Bool {
        return String.guidPred.evaluate(with: self)
    }
    
    func isoToDate() -> Date? {
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withFullDate]  // ignores time!
        return isoDateFormatter.date(from: self)
    }
    
    subscript(range: NSRange) -> Substring {
        get {
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: self) else {
                return ""
            }
            return self[swiftRange]
        }
    }
    
    /// Title-cased string is a string that has the first letter of each word capitalised (except for prepositions, articles and conjunctions)
    var localizedTitleCasedString: String {
        var newStr: String = ""
        
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        let range = NSRange(location: 0, length: self.utf16.count)
        tagger.string = self
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: []) { tag, tokenRange, _ in
            let word = self[tokenRange]
            
            guard let tag = tag else {
                newStr.append(contentsOf: word)
                return
            }
            
            if word == "VC" {
                newStr.append(contentsOf: word)
            } else if tag == .conjunction || tag == .preposition || tag == .determiner {
                newStr.append(contentsOf: word.localizedLowercase)
            } else {
                newStr.append(contentsOf: word.localizedCapitalized)
            }
        }
        return newStr
    }
    
    func addNewLines() -> String {
        let components = self.components(separatedBy: ". ")
        let joined = components.joined(separator: ".\n\n")
        return joined
    }
    
    func cleanASCII() -> String {
        var work = self.replacingOccurrences(of: "ø", with: "o")
        work = work.replacingOccurrences(of: "é", with: "e")
        work = work.replacingOccurrences(of: "ž", with: "z")
        work = work.replacingOccurrences(of: "é", with: "e")
        work = work.replacingOccurrences(of: "č", with: "c")
        work = work.replacingOccurrences(of: "ú", with: "u")
        work = work.replacingOccurrences(of: "ü", with: "u")
        work = work.replacingOccurrences(of: "ł", with: "l")
        work = work.replacingOccurrences(of: "æ", with: "ae")
        work = work.replacingOccurrences(of: "ã", with: "a")
        work = work.replacingOccurrences(of: "í", with: "i")
        work = work.replacingOccurrences(of: "á", with: "a")
        work = work.replacingOccurrences(of: "ņ", with: "n")
        work = work.replacingOccurrences(of: "š", with: "s")
        return work
    }
    
    // CSV-compliant quoting:
    // - Quote if the field contains comma, double-quote, newline, carriage return, or tab.
    // - Escape internal quotes by doubling them per RFC 4180.
    func quotedIfNeededCSV() -> String {
        let s = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsQuoting = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") || s.contains("\t")
        if needsQuoting {
            let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return s
        }
    }
    
    // Force-quoted variant using the same CSV-compliant escaping.
    func quotedCSV() -> String {
        let s = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    func isISO8601ZuluOnly() -> Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("Z") else { return false }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime] // still validates the rest
        return formatter.date(from: trimmed) != nil
    }
    
    func isISO8601InternetDateTime() -> Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return false }
        
        // Note: This will reject fractional seconds unless you add .withFractionalSeconds.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime] // yyyy-MM-dd'T'HH:mm:ssZ
        return formatter.date(from: trimmed) != nil
    }
    
    func isAllUppercase() -> Bool {
        return !isEmpty && allSatisfy( \.isUppercase )
    }
    
    /// Returns true if the string contains no lowercase letters.
    func containsNoLowercaseLetters() -> Bool {
        return !self.contains { $0.isLowercase }
    }
    
    /// Returns true if the string contains no lowercase letters, **except** for 'ß'.
    func containsNoLowercaseLettersExceptEszett() -> Bool {
        return !self.contains { $0.isLowercase && $0 != "ß" }
    }
    
    func nilIfEmpty() -> String? {
        return self.isEmpty ? nil : self
    }
    
    func intFromString() -> Int? {
        // Try to extract number ignoring commas or extra chars
        let filtered = self.filter { "0123456789".contains($0) }
        return Int(filtered)
    }
    
    func doubleFromString() -> Double? {
        // Try to extract number ignoring commas or extra chars
        let filtered = self.filter { "0123456789.".contains($0) }
        return Double(filtered)
    }
}

public extension Optional where Wrapped == String {
    func nilIfEmpty() -> String? {
        guard let s = self, s.isEmpty == false else { return nil }
        return s
    }
}

public extension Array<String> {
    static let and: String = "and"
    
    func oxfordJoin(delimiter: String) -> String {
        var temp: [String] = []
        temp.append(contentsOf: self)
        if temp.isEmpty {
            return ""
        }
        
        guard let last = temp.popLast() else {
            return ""
        }
        if temp.count > 1 {
            let result = temp.joined(separator: delimiter) + delimiter.trimmingCharacters(in: .whitespacesAndNewlines) + " \(Array<String>.and) " + last
            return result
        } else if temp.count == 1 {
            let result = (temp.first ?? "") + " \(Array<String>.and) " + last
            return result
        } else {
            let result = last
            return result
        }
    }
    
}
