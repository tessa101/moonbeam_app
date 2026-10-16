import SwiftUI

/// A sentence line keeps native text wrapping. Its token is drawn through a
/// real button using exactly the same text layout, so press feedback changes
/// the ink without moving surrounding words or altering the line's size.
struct SentenceLine: View {
    let text: Text
    let scale: CGFloat
    let usesFixedHeight: Bool
    let token: MadlibFormatter.Token?
    let onOpen: (MadlibFormatter.Token.Kind) -> Void
    var onTokenFrames: (MadlibFormatter.Token.Kind, [CGRect]) -> Void = { _, _ in }

    @ScaledMetric(relativeTo: .title) private var fullSize = Theme.Fonts.sentenceSize
    @State private var fragments: [CGRect] = []

    private var fullLineHeight: CGFloat { fullSize * Theme.Fonts.sentenceLineHeightMultiple }

    private var ink: some View {
        text.font(Theme.Fonts.sentence(fixedSize: fullSize * scale))
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        ink
            .textRenderer(SentenceTokenRenderer(mode: fragments.isEmpty ? .all : .words, knownFragments: fragments) { rects in
                if fragments != rects { fragments = rects }
            })
            .accessibilityHidden(true)
            .overlay(alignment: .topLeading) {
                if let token, !fragments.isEmpty {
                    GeometryReader { proxy in
                        let geometry = SentenceTokenGeometry(fragments: fragments, kind: token.kind, lineHeight: fullLineHeight)
                        let localRects = geometry.localRects
                        Button { onOpen(token.kind) } label: {
                            ink
                                .textRenderer(SentenceTokenRenderer(mode: .token))
                                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                                .offset(x: -geometry.bounds.minX, y: -geometry.bounds.minY)
                                .frame(width: geometry.bounds.width, height: geometry.bounds.height, alignment: .topLeading)
                        }
                        .buttonStyle(SentenceTokenButtonStyle(rects: localRects))
                        .accessibilityHidden(false)
                        .accessibilityLabel(Text(token.accessibilityLabel))
                        .accessibilityHint(token.kind == .date ? "Opens the calendar" : "Opens search")
                        .onGeometryChange(for: [CGRect].self) { proxy in
                            let origin = proxy.frame(in: .global).origin
                            return localRects.map { $0.offsetBy(dx: origin.x, dy: origin.y) }
                        } action: { rects in
                            onTokenFrames(token.kind, rects)
                        }
                        .position(x: geometry.bounds.midX, y: geometry.bounds.midY)
                    }
                }
            }
            .frame(minHeight: fullLineHeight, maxHeight: usesFixedHeight ? fullLineHeight : nil)
    }
}

/// One marker covers the icon, its attached space and the underlined words.
struct SentenceTokenAttribute: TextAttribute {}

/// Only CGRect values cross to the main actor; the layout stays in its draw
/// callback. Reporting on the next actor turn avoids mutating view state
/// during drawing. Equality in SentenceLine prevents a render feedback loop.
struct SentenceTokenRenderer: TextRenderer {
    enum Mode { case all, words, token }
    var mode: Mode
    var knownFragments: [CGRect] = []
    var onFragments: (@MainActor @Sendable ([CGRect]) -> Void)?

    init(mode: Mode, knownFragments: [CGRect] = [], onFragments: (@MainActor @Sendable ([CGRect]) -> Void)? = nil) {
        self.mode = mode
        self.knownFragments = knownFragments
        self.onFragments = onFragments
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var fragments: [CGRect] = []
        for line in layout {
            var fragment = CGRect.null
            for run in line {
                let isToken = run[SentenceTokenAttribute.self] != nil
                if isToken { fragment = fragment.union(run.typographicBounds.rect) }
                if mode == .all || (mode == .token) == isToken {
                    context.draw(run)
                }
            }
            if !fragment.isNull { fragments.append(fragment) }
        }
        if fragments != knownFragments, let onFragments {
            Task { @MainActor in onFragments(fragments) }
        }
    }
}

/// Expand date fragments upward and place fragments downward. This keeps
/// 44 pt targets apart on the close-set date/place lines without changing
/// the sentence's typography. Wrapped fragments form one button per token.
struct SentenceTokenGeometry {
    let rects: [CGRect]
    let bounds: CGRect

    init(fragments: [CGRect], kind: MadlibFormatter.Token.Kind, lineHeight: CGFloat) {
        rects = fragments.map { rect in
            let width = max(rect.width, Theme.Metrics.minimumHitTarget)
            // Young Serif's typographic descent extends into the next
            // line's box. Use the actual line advance for touch geometry;
            // token ink remains unclipped, just like the original Text.
            let naturalHeight = min(rect.height, lineHeight)
            let height = max(naturalHeight, Theme.Metrics.minimumHitTarget)
            return CGRect(x: rect.midX - width / 2,
                          y: kind == .date ? rect.minY + naturalHeight - height : rect.minY,
                          width: width, height: height)
        }
        bounds = rects.reduce(CGRect.null) { $0.union($1) }
    }

    var localRects: [CGRect] { rects.map { $0.offsetBy(dx: -bounds.minX, dy: -bounds.minY) } }
}

nonisolated private struct SentenceTokenHitShape: Shape {
    let rects: [CGRect]
    func path(in rect: CGRect) -> Path {
        Path { path in for fragment in rects { path.addRect(fragment) } }
    }
}

/// The shared 100 ms press hold and Reduce Motion behavior, with a shape
/// matching only this token's fragments rather than the whole wrapped line.
private struct SentenceTokenButtonStyle: ButtonStyle {
    let rects: [CGRect]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(SentenceTokenHitShape(rects: rects))
    }
}
