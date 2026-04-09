import Foundation
import ZIPFoundation

nonisolated struct XLSXParserService: Sendable {
    static func parseToCSV(url: URL) -> String? {
        guard let archive = Archive(url: url, accessMode: .read) else { return nil }

        let sharedStrings = extractSharedStrings(from: archive)
        guard let worksheetXML = extractFirstWorksheet(from: archive) else { return nil }
        guard let rows = parseWorksheetRows(xml: worksheetXML, sharedStrings: sharedStrings) else { return nil }
        guard !rows.isEmpty else { return nil }

        let maxCol = rows.flatMap(\.keys).max() ?? 0
        var csvLines: [String] = []

        for row in rows.sorted(by: { $0.keys.min() ?? 0 < $1.keys.min() ?? 0 }) {
            var cellValues: [String] = []
            for col in 0...maxCol {
                let value = row[col] ?? ""
                cellValues.append(escapeCSVField(value))
            }
            csvLines.append(cellValues.joined(separator: ","))
        }

        let result = csvLines.joined(separator: "\n")
        return result.isEmpty ? nil : result
    }

    private static func extractData(from archive: Archive, path: String) -> Data? {
        guard let entry = archive[path] else { return nil }
        var result = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                result.append(chunk)
            }
            return result
        } catch {
            return nil
        }
    }

    private static func extractSharedStrings(from archive: Archive) -> [String] {
        guard let data = extractData(from: archive, path: "xl/sharedStrings.xml") else { return [] }
        let parser = SharedStringsParser(data: data)
        return parser.parse()
    }

    private static func extractFirstWorksheet(from archive: Archive) -> Data? {
        if let data = extractData(from: archive, path: "xl/worksheets/sheet1.xml") {
            return data
        }
        guard let wbData = extractData(from: archive, path: "xl/workbook.xml") else { return nil }
        let wbParser = WorkbookParser(data: wbData)
        let sheetNames = wbParser.parse()
        guard !sheetNames.isEmpty else { return nil }

        for i in 1...sheetNames.count {
            if let data = extractData(from: archive, path: "xl/worksheets/sheet\(i).xml") {
                return data
            }
        }
        return nil
    }

    private static func parseWorksheetRows(xml: Data, sharedStrings: [String]) -> [[Int: String]]? {
        let parser = WorksheetParser(data: xml, sharedStrings: sharedStrings)
        return parser.parse()
    }

    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private var strings: [String] = []
    private var currentText = ""
    private var inSI = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if elementName == "si" {
            inSI = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inSI {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "si" {
            strings.append(currentText)
            inSI = false
        }
    }
}

private final class WorkbookParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private var sheetNames: [String] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return sheetNames
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if elementName == "sheet", let name = attributes["name"] {
            sheetNames.append(name)
        }
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private let sharedStrings: [String]
    private var rows: [[Int: String]] = []
    private var currentRow: [Int: String] = [:]
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var inCell = false
    private var inValue = false
    private var inRow = false
    private var inInlineString = false
    private var inlineText = ""

    init(data: Data, sharedStrings: [String]) {
        self.data = data
        self.sharedStrings = sharedStrings
    }

    func parse() -> [[Int: String]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "row":
            inRow = true
            currentRow = [:]
        case "c":
            inCell = true
            currentCellRef = attributes["r"] ?? ""
            currentCellType = attributes["t"] ?? ""
            currentValue = ""
            inlineText = ""
        case "v":
            inValue = true
            currentValue = ""
        case "is":
            inInlineString = true
            inlineText = ""
        case "t":
            if inInlineString {
                currentValue = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue {
            currentValue += string
        } else if inInlineString {
            inlineText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "row":
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
            inRow = false
        case "c":
            let colIndex = columnIndex(from: currentCellRef)
            var cellValue = ""

            if currentCellType == "s", let idx = Int(currentValue), idx < sharedStrings.count {
                cellValue = sharedStrings[idx]
            } else if currentCellType == "inlineStr" || !inlineText.isEmpty {
                cellValue = inlineText
            } else {
                cellValue = currentValue
            }

            currentRow[colIndex] = cellValue
            inCell = false
        case "v":
            inValue = false
        case "is":
            inInlineString = false
        default:
            break
        }
    }

    private func columnIndex(from cellRef: String) -> Int {
        let letters = cellRef.prefix(while: { $0.isLetter })
        var index = 0
        for char in letters.uppercased() {
            index = index * 26 + Int(char.asciiValue! - Character("A").asciiValue!) + 1
        }
        return index - 1
    }
}
