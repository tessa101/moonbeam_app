//
//  SVGPathData.swift
//  moonbeam-app
//

import SwiftUI

/// A path from the illustration SVGs' `d` data, so the spark rides the
/// art's own route and the star is the doc's shape, not a redraw
/// (STEP-5.10a, Chunk 5).
///
/// Only what those paths use: absolute M, L, H, V, C, S, Q and Z. Anything
/// else ends the path there.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated enum SVGPathData {

    /// `d`, moved by `offset` (the art's `translate(dx -130)`), in viewBox
    /// units.
    static func path(_ d: String, offset: CGPoint = .zero) -> Path {
        var path = Path()
        var tokens = Scanner(d)
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: x + offset.x, y: y + offset.y)
        }

        while let next = tokens.peek() {
            if next.isLetter {
                command = next
                tokens.skip()
            }
            switch command {
            case "M":
                guard let x = tokens.number(), let y = tokens.number() else { return path }
                current = point(x, y)
                start = current
                path.move(to: current)
                lastControl = nil
                // Further pairs after M are lines.
                command = "L"
            case "L":
                guard let x = tokens.number(), let y = tokens.number() else { return path }
                current = point(x, y)
                path.addLine(to: current)
                lastControl = nil
            case "H":
                guard let x = tokens.number() else { return path }
                current = CGPoint(x: x + offset.x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case "V":
                guard let y = tokens.number() else { return path }
                current = CGPoint(x: current.x, y: y + offset.y)
                path.addLine(to: current)
                lastControl = nil
            case "C":
                guard let x1 = tokens.number(), let y1 = tokens.number(),
                      let x2 = tokens.number(), let y2 = tokens.number(),
                      let x = tokens.number(), let y = tokens.number() else { return path }
                let control2 = point(x2, y2)
                current = point(x, y)
                path.addCurve(to: current, control1: point(x1, y1), control2: control2)
                lastControl = control2
            case "S":
                guard let x2 = tokens.number(), let y2 = tokens.number(),
                      let x = tokens.number(), let y = tokens.number() else { return path }
                // The first control is the last one's reflection.
                let reflected = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let control2 = point(x2, y2)
                current = point(x, y)
                path.addCurve(to: current, control1: reflected, control2: control2)
                lastControl = control2
            case "Q":
                guard let x1 = tokens.number(), let y1 = tokens.number(),
                      let x = tokens.number(), let y = tokens.number() else { return path }
                current = point(x, y)
                path.addQuadCurve(to: current, control: point(x1, y1))
                lastControl = nil
            case "Z", "z":
                path.closeSubpath()
                current = start
                lastControl = nil
                if tokens.peek()?.isLetter == false { return path }
            default:
                return path
            }
        }
        return path
    }

    /// Numbers and command letters, in order.
    private struct Scanner {
        private let characters: [Character]
        private var index = 0

        init(_ text: String) {
            characters = Array(text)
        }

        mutating func peek() -> Character? {
            skipSeparators()
            return index < characters.count ? characters[index] : nil
        }

        mutating func skip() {
            index += 1
        }

        mutating func number() -> Double? {
            skipSeparators()
            let begin = index
            if index < characters.count, characters[index] == "-" || characters[index] == "+" { index += 1 }
            while index < characters.count, characters[index].isNumber || characters[index] == "." {
                index += 1
            }
            guard index > begin else { return nil }
            return Double(String(characters[begin..<index]))
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," {
                index += 1
            }
        }
    }
}
