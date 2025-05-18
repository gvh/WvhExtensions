//
//  ParseTsv.swift
//  AirSimulation
//
//  Created by Gardner von Holt on 2/24/24.
//

import Foundation

public class ParseTsv {
    public static func convertToArray(resource: String) -> [TsvRow] {
        var tsvRows: [TsvRow] = []

        // locate the file you want to use
        guard let filepath = Bundle.main.path(forResource: resource, ofType: "tsv") else {
            return tsvRows
        }

        // convert that file into one long string
        var data = ""
        do {
            data = try String(contentsOfFile: filepath)
        } catch {
            print(error)
            return tsvRows
        }

        // now split that string into an array of "rows" of data.  Each row is a string.
        var rows = data.components(separatedBy: "\n")

        // if you have a header row, remove it here
        let labelString = rows.first?.removeTrailing("\r") ?? ""
        rows.removeFirst()

        // now loop around each row, and split it into each of its columns
        for row in rows where row.isNotEmpty {
            let tsvRow = TsvRow(labelString: labelString, valueString: row)
            tsvRows.append(tsvRow)
        }
        return tsvRows
    }
}

public class TsvRow {
    var columns: [String: String] = [:]

    init(labelString: String, valueString: String) {
        let labels = labelString.components(separatedBy: "\t")
        let values = valueString.removeTrailing("\r").components(separatedBy: "\t")
        for colNum in 0..<labels.count where colNum < values.count {
            columns[labels[colNum]] = values[colNum]
        }
    }


    subscript(index: String) -> String? {
        get {
            return columns[index]
        }

        set(newElm) {
            columns[index] = newElm
        }
    }
}
