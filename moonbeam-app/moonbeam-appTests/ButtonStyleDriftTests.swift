//
//  ButtonStyleDriftTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// Every `Button` in the app target uses a shared style (STEP-5.13 §4, Build
/// 5.13.3 part 3), so every control shows the held pressed look. A new button
/// left on the system style, or moved to `.plain`, fails here.
///
/// The test reads the app's sources (beside this file) rather than a view
/// tree: a button's style can come from any container above it, and a view
/// tree can't be walked from a test. For each `Button(…)` / `Button { … }`
/// it follows the button's modifier chain, then each enclosing view's, and
/// takes the innermost `.buttonStyle(…)`, as SwiftUI does. Comments and
/// string literals are blanked first, so neither can hide nor fake a button.
///
/// "Shared" means a `ButtonStyle` whose body applies `.pressFeedback(…)`, used
/// by its type or by a static name in `extension ButtonStyle where Self == …`.
///
/// Toolbar buttons are the exception, the other way round: inside `.toolbar`,
/// `ToolbarItem` or `ToolbarItemGroup` a button must keep the system style
/// (STEP-5.13 §4, corrected in 5.13.3c). Any custom style there turns the bar
/// item into a squeezed custom view ("Tod…" on the calendar sheet) and drops
/// the system's disabled look; the bar's glass gives the press feedback.
@Suite("Button style drift", .timeLimit(.minutes(1)))
struct ButtonStyleDriftTests {

    // MARK: - Exceptions

    /// Unstyled buttons allowed per file (path from the app folder), with why.
    /// The count is exact, so a fixed entry fails until it's removed here.
    static let allowlist: [String: (count: Int, reason: String)] = [:]

    /// Styles with their own pressed look that still hold it for
    /// `PressHold.minimum` (checked in `ownHeldStylesHoldTheMinimum`).
    static let ownHeldStyles: Set<String> = [
        // The ‹ › arrows' 0.88 scale and fill (MOONCARD §9.20).
        "DayStepButtonStyle",
    ]

    // MARK: - Tests

    @Test("Every Button in the app uses a shared style")
    func everyButtonUsesASharedStyle() throws {
        let sources = try Self.appSources()
        let shared = Self.sharedStyles(in: sources.map(\.code))
        #expect(!shared.types.isEmpty, "Found no shared ButtonStyle; is the scan reading the app?")

        var unstyled: [String: [String]] = [:]
        var buttonCount = 0
        var toolbarCount = 0
        for source in sources {
            for button in Self.buttons(in: source.code) {
                buttonCount += 1
                let line = Self.lineNumber(of: button.offset, in: source.code)
                if button.isInToolbar {
                    toolbarCount += 1
                    #expect(
                        button.style == nil,
                        "\(source.path) line \(line): toolbar Button on \(button.style ?? "") (keep the system style, 5.13.3c)"
                    )
                    continue
                }
                if let style = button.style, Self.isShared(style, shared) { continue }
                unstyled[source.path, default: []].append("line \(line): \(button.style ?? "no style")")
            }
        }

        // The app has ~30 buttons; far fewer means the scan broke, not the app.
        #expect(buttonCount >= 25, "Only \(buttonCount) buttons found")
        // The calendar sheet's Today, Cancel and Done.
        #expect(toolbarCount >= 3, "Only \(toolbarCount) toolbar buttons found; is the toolbar check working?")

        for (path, found) in unstyled.sorted(by: { $0.key < $1.key }) {
            let allowed = Self.allowlist[path]?.count ?? 0
            #expect(
                found.count <= allowed,
                "\(path): Button without a shared style (STEP-5.13 §4): \(found.joined(separator: "; "))"
            )
        }
        for (path, entry) in Self.allowlist {
            let found = unstyled[path]?.count ?? 0
            #expect(
                found == entry.count,
                "Allowlist for \(path) (\(entry.reason)) expects \(entry.count), found \(found); update it"
            )
        }
    }

    @Test("Styles with their own look still hold it for PressHold.minimum")
    @MainActor
    func ownHeldStylesHoldTheMinimum() {
        #expect(Self.ownHeldStyles == ["DayStepButtonStyle"])
        #expect(DayStepButtonStyle.minimumPressedDuration == PressHold.minimum)
    }

    @Test("The scan: own style, container style, innermost wins, .plain fails, toolbars, comments and strings ignored")
    func scanner() {
        let source = """
        struct Held: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label.pressFeedback(isPressed: configuration.isPressed)
            }
        }
        extension ButtonStyle where Self == Held { static var held: Held { Held() } }
        struct Loose: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View { configuration.label }
        }
        struct V: View {
            var body: some View {
                VStack {
                    Button("a") {}
                        .buttonStyle(.held)
                    Button(action: {}) { Text("\\(flag ? "b)" : "c{")") } // Button("in a comment")
                    Button { } label: { Text("d") }
                        .padding()
                        .buttonStyle(.plain)
                    if flag {
                        Button("e", action: go)
                    }
                    Button("f") {}
                        .buttonStyle(Loose())
                    /* Button("in a block comment") */
                }
                .buttonStyle(Held())
                Button("g", action: go)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("h", action: go)
                                .disabled(flag)
                        }
                        ToolbarItemGroup {
                            Button("i") {}
                                .buttonStyle(.held)
                        }
                    }
            }
        }
        """
        let code = Self.blankingCommentsAndStrings(source)
        let shared = Self.sharedStyles(in: [code])
        #expect(shared.types == ["Held"])
        #expect(shared.names == ["held": "Held"])

        let buttons = Self.buttons(in: code)
        let styles = buttons.map(\.style)
        #expect(styles == [".held", "Held()", ".plain", "Held()", "Loose()", nil, nil, ".held"])
        #expect(styles.map { $0.map { Self.isShared($0, shared) } ?? false }
            == [true, true, false, true, false, false, false, true])
        // h is a system toolbar button (passes); i has a custom style in a toolbar (fails the rule).
        #expect(buttons.map(\.isInToolbar) == [false, false, false, false, false, false, true, true])
    }

    // MARK: - Sources

    struct Source {
        /// From the app folder, e.g. `Features/Location/MadlibSentence.swift`.
        let path: String
        let code: [UInt8]
    }

    /// The app target's Swift files, from beside this test file.
    static func appSources(filePath: String = #filePath) throws -> [Source] {
        let app = URL(filePath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "moonbeam-app")
        let enumerator = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)
        var sources: [Source] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let path = String(url.standardizedFileURL.path.dropFirst(app.standardizedFileURL.path.count + 1))
            let text = try String(contentsOf: url, encoding: .utf8)
            sources.append(Source(path: path, code: blankingCommentsAndStrings(text)))
        }
        #expect(sources.count > 50, "Found \(sources.count) app sources at \(app.path)")
        return sources
    }

    // MARK: - Shared styles

    struct SharedStyles {
        /// `ButtonStyle` types whose body applies `.pressFeedback(`.
        var types: Set<String> = []
        /// Static names (`.primary`) → type.
        var names: [String: String] = [:]
    }

    static func sharedStyles(in files: [[UInt8]]) -> SharedStyles {
        var shared = SharedStyles()
        for code in files {
            let text = String(decoding: code, as: UTF8.self)
            for match in text.matches(of: /struct\s+(\w+)\s*:\s*(?:Primitive)?ButtonStyle\b[^{]*\{/) {
                let open = text.utf8.distance(from: text.startIndex, to: match.range.upperBound) - 1
                guard let close = matching(code, open) else { continue }
                if String(decoding: code[open...close], as: UTF8.self).contains(".pressFeedback(") {
                    shared.types.insert(String(match.1))
                }
            }
        }
        for code in files {
            let text = String(decoding: code, as: UTF8.self)
            for match in text.matches(of: /extension\s+ButtonStyle\s+where\s+Self\s*==\s*(\w+)\s*\{/) {
                let type = String(match.1)
                guard shared.types.contains(type) else { continue }
                let open = text.utf8.distance(from: text.startIndex, to: match.range.upperBound) - 1
                guard let close = matching(code, open) else { continue }
                let body = String(decoding: code[open...close], as: UTF8.self)
                for name in body.matches(of: /static\s+(?:var|func)\s+(\w+)/) {
                    shared.names[String(name.1)] = type
                }
            }
        }
        return shared
    }

    /// `.name`, `.name(…)`, `Type(…)` or `Type.init(…)` of a shared or own-held style.
    static func isShared(_ style: String, _ shared: SharedStyles) -> Bool {
        let leading = style.prefix { $0 == "." || $0.isLetter || $0.isNumber || $0 == "_" }
        if leading.hasPrefix(".") {
            return shared.names[String(leading.dropFirst())] != nil
        }
        let type = String(leading.split(separator: ".").first ?? "")
        return shared.types.contains(type) || ownHeldStyles.contains(type)
    }

    // MARK: - Buttons

    struct FoundButton {
        let offset: Int
        /// The innermost `.buttonStyle(…)` argument, trimmed, or nil.
        let style: String?
        /// Inside `.toolbar { … }`, `ToolbarItem` or `ToolbarItemGroup`.
        let isInToolbar: Bool
    }

    static func buttons(in code: [UInt8]) -> [FoundButton] {
        let name = Array("Button".utf8)
        var found: [FoundButton] = []
        var i = 0
        while i + name.count <= code.count {
            defer { i += 1 }
            guard code[i..<(i + name.count)].elementsEqual(name),
                  i == 0 || !isIdentifier(code[i - 1]) && code[i - 1] != UInt8(ascii: "."),
                  i + name.count == code.count || !isIdentifier(code[i + name.count])
            else { continue }
            var end = skipSpace(code, i + name.count)
            guard end < code.count, code[end] == UInt8(ascii: "(") || code[end] == UInt8(ascii: "{") else { continue }
            if code[end] == UInt8(ascii: "("), let close = matching(code, end) { end = close + 1 }
            end = skipTrailingClosures(code, end)
            found.append(FoundButton(
                offset: i,
                style: style(for: i, end: end, in: code),
                isInToolbar: isInToolbar(i, in: code)
            ))
        }
        return found
    }

    /// The button's own chain, then each enclosing view's, innermost first.
    private static func style(for start: Int, end: Int, in code: [UInt8]) -> String? {
        if let style = buttonStyle(inChainAt: end, in: code) { return style }
        var inner = start
        while let open = enclosingOpener(of: inner, in: code), let close = matching(code, open) {
            if let style = buttonStyle(inChainAt: close + 1, in: code) { return style }
            inner = open
        }
        return nil
    }

    private static let toolbarNames: Set<String> = ["toolbar", "ToolbarItem", "ToolbarItemGroup"]

    /// Whether any bracket around `index` belongs to a toolbar: `name {`,
    /// `name(…) {` or `name(`.
    private static func isInToolbar(_ index: Int, in code: [UInt8]) -> Bool {
        var inner = index
        while let open = enclosingOpener(of: inner, in: code) {
            var end = open
            if code[open] == UInt8(ascii: "{") {
                end = skipSpaceBackward(code, open - 1) + 1
                if end > 0, code[end - 1] == UInt8(ascii: ")"), let callOpen = openingBracket(of: end - 1, in: code) {
                    end = callOpen
                }
            }
            var start = end
            while start > 0, isIdentifier(code[start - 1]) { start -= 1 }
            if toolbarNames.contains(String(decoding: code[start..<end], as: UTF8.self)) { return true }
            inner = open
        }
        return false
    }

    /// The last index at or before `index` that isn't whitespace.
    private static func skipSpaceBackward(_ code: [UInt8], _ index: Int) -> Int {
        var i = index
        while i >= 0, [UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\t"), UInt8(ascii: "\r")]
            .contains(code[i]) { i -= 1 }
        return i
    }

    /// The bracket that opens the one closing at `close`.
    private static func openingBracket(of close: Int, in code: [UInt8]) -> Int? {
        var depth = 0
        var i = close
        while i >= 0 {
            if closers.contains(code[i]) { depth += 1 }
            if openers[code[i]] != nil {
                depth -= 1
                if depth == 0 { return i }
            }
            i -= 1
        }
        return nil
    }

    /// Walks `.modifier(…) { … } label: { … }` links from `index`.
    private static func buttonStyle(inChainAt index: Int, in code: [UInt8]) -> String? {
        var i = skipSpace(code, index)
        while i < code.count, code[i] == UInt8(ascii: ".") {
            let nameStart = i + 1
            var nameEnd = nameStart
            while nameEnd < code.count, isIdentifier(code[nameEnd]) { nameEnd += 1 }
            guard nameEnd > nameStart else { return nil }
            let modifier = String(decoding: code[nameStart..<nameEnd], as: UTF8.self)
            i = skipSpace(code, nameEnd)
            if i < code.count, code[i] == UInt8(ascii: "("), let close = matching(code, i) {
                if modifier == "buttonStyle" {
                    return String(decoding: code[(i + 1)..<close], as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                i = close + 1
            }
            i = skipSpace(code, skipTrailingClosures(code, i))
        }
        return nil
    }

    /// Past `{ … }` and `label: { … }` trailing closures.
    private static func skipTrailingClosures(_ code: [UInt8], _ index: Int) -> Int {
        var end = index
        while true {
            var i = skipSpace(code, end)
            if i < code.count, code[i] != UInt8(ascii: "{") {
                // A labeled trailing closure: `name:` then `{`.
                var nameEnd = i
                while nameEnd < code.count, isIdentifier(code[nameEnd]) { nameEnd += 1 }
                guard nameEnd > i else { return end }
                i = skipSpace(code, nameEnd)
                guard i < code.count, code[i] == UInt8(ascii: ":") else { return end }
                i = skipSpace(code, i + 1)
            }
            guard i < code.count, code[i] == UInt8(ascii: "{"), let close = matching(code, i) else { return end }
            end = close + 1
        }
    }

    // MARK: - Brackets

    private static let openers: [UInt8: UInt8] = [
        UInt8(ascii: "("): UInt8(ascii: ")"),
        UInt8(ascii: "{"): UInt8(ascii: "}"),
        UInt8(ascii: "["): UInt8(ascii: "]"),
    ]
    private static let closers = Set(openers.values)

    /// The bracket that closes the one at `open`.
    static func matching(_ code: [UInt8], _ open: Int) -> Int? {
        var depth = 0
        for i in open..<code.count {
            if openers[code[i]] != nil { depth += 1 }
            if closers.contains(code[i]) {
                depth -= 1
                if depth == 0 { return i }
            }
        }
        return nil
    }

    /// The innermost bracket still open at `index`.
    private static func enclosingOpener(of index: Int, in code: [UInt8]) -> Int? {
        var depth = 0
        var i = index - 1
        while i >= 0 {
            if closers.contains(code[i]) { depth += 1 }
            if openers[code[i]] != nil {
                if depth == 0 { return i }
                depth -= 1
            }
            i -= 1
        }
        return nil
    }

    private static func skipSpace(_ code: [UInt8], _ index: Int) -> Int {
        var i = index
        while i < code.count, [UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\t"), UInt8(ascii: "\r")]
            .contains(code[i]) { i += 1 }
        return i
    }

    private static func isIdentifier(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || byte == UInt8(ascii: "_")
    }

    private static func lineNumber(of offset: Int, in code: [UInt8]) -> Int {
        code[..<offset].filter { $0 == UInt8(ascii: "\n") }.count + 1
    }

    // MARK: - Comments and strings

    private enum Mode {
        /// Code; `depth` counts parens inside a string interpolation.
        case code(depth: Int)
        case string(multiline: Bool)
    }

    /// The source with comments and string contents turned to spaces
    /// (newlines kept, so offsets and line numbers still match). Code inside
    /// `\(…)` stays, and strings nested in it are followed.
    static func blankingCommentsAndStrings(_ source: String) -> [UInt8] {
        var code = Array(source.utf8)
        let space = UInt8(ascii: " "), newline = UInt8(ascii: "\n")
        let quote = UInt8(ascii: "\""), slash = UInt8(ascii: "/"), star = UInt8(ascii: "*")
        let backslash = UInt8(ascii: "\\")
        func blank(_ range: Range<Int>) {
            for i in range where i < code.count && code[i] != newline { code[i] = space }
        }
        func at(_ i: Int, _ text: String) -> Bool {
            let bytes = Array(text.utf8)
            return i + bytes.count <= code.count && code[i..<(i + bytes.count)].elementsEqual(bytes)
        }
        var stack: [Mode] = [.code(depth: 0)]
        var i = 0
        while i < code.count {
            switch stack[stack.count - 1] {
            case .code(let depth):
                if code[i] == slash, i + 1 < code.count, code[i + 1] == slash {
                    var end = i
                    while end < code.count, code[end] != newline { end += 1 }
                    blank(i..<end)
                    i = end
                } else if code[i] == slash, i + 1 < code.count, code[i + 1] == star {
                    var nesting = 0
                    var end = i
                    repeat {
                        if at(end, "/*") { nesting += 1; end += 2 } else if at(end, "*/") { nesting -= 1; end += 2 } else { end += 1 }
                    } while nesting > 0 && end < code.count
                    blank(i..<end)
                    i = end
                } else if at(i, "\"\"\"") {
                    blank(i..<(i + 3))
                    stack.append(.string(multiline: true))
                    i += 3
                } else if code[i] == quote {
                    blank(i..<(i + 1))
                    stack.append(.string(multiline: false))
                    i += 1
                } else if stack.count > 1, code[i] == UInt8(ascii: "(") {
                    stack[stack.count - 1] = .code(depth: depth + 1)
                    i += 1
                } else if stack.count > 1, code[i] == UInt8(ascii: ")") {
                    if depth == 0 {
                        // The interpolation's own `)`: back into the string.
                        blank(i..<(i + 1))
                        stack.removeLast()
                    } else {
                        stack[stack.count - 1] = .code(depth: depth - 1)
                    }
                    i += 1
                } else {
                    i += 1
                }
            case .string(let multiline):
                if code[i] == backslash, i + 1 < code.count, code[i + 1] == UInt8(ascii: "(") {
                    blank(i..<(i + 2))
                    stack.append(.code(depth: 0))
                    i += 2
                } else if code[i] == backslash {
                    blank(i..<(i + 2))
                    i += 2
                } else if multiline ? at(i, "\"\"\"") : code[i] == quote {
                    let length = multiline ? 3 : 1
                    blank(i..<(i + length))
                    stack.removeLast()
                    i += length
                } else {
                    blank(i..<(i + 1))
                    i += 1
                }
            }
        }
        return code
    }
}
