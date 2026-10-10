//
//  FailureLoadIn.swift
//  moonbeam-app
//

import SwiftUI

/// The failure screen's loader handoff (STEP-5.10a Chunk 6). The screen uses
/// the existing content load-in motion; only the block order is specific to
/// this message.
struct FailureLoadIn: ViewModifier {
    enum Block: Equatable {
        case illustration, headline, body, path, primary, secondary
    }

    let block: Block
    let hasPath: Bool
    let isEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIn = false

    static func delay(for block: Block, hasPath: Bool) -> TimeInterval {
        let index: Int = switch block {
        case .illustration: 0
        case .headline: 1
        case .body: 2
        case .path: 3
        case .primary: hasPath ? 4 : 3
        case .secondary: hasPath ? 5 : 4
        }
        return Double(index) * ContentLoadIn.stagger
    }

    static func startOffset(reduceMotion: Bool) -> CGFloat {
        ContentLoadIn.startOffset(reduceMotion: reduceMotion)
    }

    func body(content: Content) -> some View {
        content
            .geometryGroup()
            .opacity(!isEnabled || isIn ? 1 : 0)
            .offset(y: !isEnabled || isIn ? 0 : Self.startOffset(reduceMotion: reduceMotion))
            .task(id: isEnabled) {
                guard isEnabled else {
                    isIn = true
                    return
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { isIn = false }
                await Task.yield()
                withAnimation(
                    .easeOut(duration: ContentLoadIn.duration)
                        .delay(Self.delay(for: block, hasPath: hasPath))
                ) {
                    isIn = true
                }
            }
    }
}

extension View {
    func failureLoadIn(_ block: FailureLoadIn.Block, hasPath: Bool, isEnabled: Bool) -> some View {
        modifier(FailureLoadIn(block: block, hasPath: hasPath, isEnabled: isEnabled))
    }
}
