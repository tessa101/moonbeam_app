//
//  LaunchPhaseCycle.swift
//  moonbeam-app
//

import SwiftUI

/// The launch loader (LOADER.md §3, §10; design concept 1a): the onboarding
/// moon on a clean screen, running through its phases over a breathing glow,
/// with "Finding your location…" under it; or, stopped, a message saying why
/// and what to do; or, found after a recovery, "Aha" and the moon flying
/// into the card's phase slot (§10.4). `LocationViewModel.launchStage` decides when it shows and
/// `LocationLoader` how the moon, glow, label and message move.
///
/// The screen's backdrop (with its faint top glow) comes from
/// `LocationScreen`, so it doesn't change when the loader comes and goes.
struct LaunchPhaseCycle: View {

    static let message = "Finding your location…"

    let loader: LocationLoader
    /// The message's primary button, except Open Settings, opened here.
    let onPrimary: () -> Void
    let onSearch: () -> Void

    /// Where "Aha"'s moon lands (§10.4): the card's phase slot, in global
    /// coordinates, and the glyph it settles on. `nil` until the screen is
    /// up under the loader.
    var landingSlot: CGRect?
    var landingGlyph: PhaseGlyphGeometry?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    /// The entrance (§10.2): the moon fades in and rises, then the label.
    @State private var moonIsIn = false
    @State private var moonHasRisen = false
    @State private var labelIsIn = false
    @State private var labelHasRisen = false

    /// Natural message heights at the two §10.5 scales. Measuring the real
    /// text (including the current Dynamic Type size) keeps the fit decision
    /// correct for every message and accessibility size.
    @State private var regularMessageHeight: CGFloat = 0
    @State private var compactMessageHeight: CGFloat = 0

    /// The moon's resting frame, in global coordinates: where the flight
    /// starts.
    @State private var moonFrame: CGRect = .zero

    // MARK: - Constants

    /// §3: the built size, over the handoff's 132 pt.
    private static let moonSize: CGFloat = 140
    /// §10.5: when the message doesn't fit, the moon gives the copy more room.
    private static let compactMoonSize: CGFloat = 96
    private static let compactMoonRise: CGFloat = 28
    private static let compactTextScale: CGFloat = 0.8
    /// The handoff puts the moon's centre 13 pt above the screen's.
    private static let moonCentreAboveScreenCentre: CGFloat = 13
    /// The mock's gap between the moon and the label.
    private static let moonToText: CGFloat = 28
    /// The handoff's message top (y 500) under its moon (bottom at 479).
    private static let moonToMessage: CGFloat = 20
    /// The handoff's 28 pt message sides and 40 pt bottom inset, from the
    /// screen's edge; never closer than this to the home indicator.
    private static let messageBottomInset: CGFloat = 40
    private static let minimumAboveHomeIndicator: CGFloat = 8
    /// The disc's tight glow: CSS `0 0 40px`, a 20 pt shadow radius
    /// (§11.3).
    private static let glyphGlowCSSBlur: CGFloat = 40
    /// The breathing glow, CSS `inset: -0.6 × size`: 2.2 moons across.
    private static let glowDiameterPerMoon: CGFloat = 2.2
    /// `accent` 32% at the centre, clear at the edge (CSS `closest-side`).
    private static let glowOpacity = 0.32

    /// The handoff's "Entrance": both rise 8 pt on `cubic-bezier(.16, 1,
    /// .3, 1)`; the moon fades in over 0.9 s and rises over 1.2 s, the label
    /// over 0.7 s and 0.9 s.
    private static let entranceRise: CGFloat = 8
    private static let moonFadeDuration: TimeInterval = 0.9
    private static let moonRiseDuration: TimeInterval = 1.2
    private static let labelFadeDuration: TimeInterval = 0.7
    private static let labelRiseDuration: TimeInterval = 0.9
    /// "Search → message": the label fades out over 0.3 s.
    private static let labelOutDuration: TimeInterval = 0.3
    /// Reduce Motion (§10.6): every step cross-fades over 0.3 s.
    private static let reduceMotionFade: TimeInterval = 0.3

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top
            let bottom = proxy.safeAreaInsets.bottom
            // §10: placed from the screen's centre, not the safe area's.
            let screenHeight = proxy.size.height + top + bottom
            let bottomInset = max(Self.messageBottomInset - bottom, Self.minimumAboveHomeIndicator)
            let layout = messageLayout(
                screenHeight: screenHeight,
                safeAreaTop: top,
                bottomInset: bottomInset
            )
            let moonSize = layout == .regular ? Self.moonSize : Self.compactMoonSize
            let moonRise = layout == .regular ? 0 : Self.compactMoonRise
            let moonTop = screenHeight / 2 - Self.moonCentreAboveScreenCentre - moonSize / 2 - top - moonRise

            VStack(spacing: 0) {
                Color.clear.frame(height: max(0, moonTop))
                moon(size: moonSize)
                ZStack(alignment: .top) {
                    label
                        .padding(.top, Self.moonToText)
                        .padding(.horizontal, Theme.Metrics.screenMargin)
                    if case .aha(let greeting) = loader.content {
                        AhaGreetingIn(leaving: loader.flightStartedAt != nil) {
                            AhaGreetingView(greeting: greeting)
                        }
                        .padding(.top, Self.moonToText)
                        .padding(.horizontal, Theme.Metrics.screenMargin)
                        .onAppear {
                            AccessibilityNotification.Announcement(greeting.accessibilityLabel).post()
                        }
                    }
                    if case .message(let issue) = loader.content {
                        message(issue, layout: layout, bottomInset: bottomInset)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .overlay {
                if case .message(let issue) = loader.content {
                    messageMeasurements(issue)
                }
            }
        }
        .onAppear(perform: enter)
        .onChange(of: loader.showsLabel) { _, shows in
            showLabel(shows)
        }
    }

    // MARK: - Moon

    private func moon(size: CGFloat) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            moon(at: context.date, size: size)
        }
        .frame(width: size, height: size)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            moonFrame = frame
        }
        .opacity(moonIsIn ? 1 : 0)
        .offset(y: moonHasRisen || reduceMotion ? 0 : Self.entranceRise)
        .accessibilityHidden(true)
    }

    /// Reduce Motion: the glyph holds at the hold phase and the glow only
    /// fades, with no swell (§10.6).
    private func moon(at date: Date, size: CGFloat) -> some View {
        let elapsed = loader.moon.elapsed(at: date)
        var look = loader.glow.look(at: date, elapsed: elapsed)
        var geometry = reduceMotion ? PhaseCycle.stillGeometry : PhaseCycle.geometry(at: elapsed)
        var glowBlur = Self.glyphGlowCSSBlur
        // §11.3: the tight glow follows the lit fraction.
        var glyphGlow = PhaseCycle.tightGlowOpacityAtFull * geometry.litFraction
        var discColor = Theme.Colors.moonEarthshine
        var scale: CGFloat = 1
        var offset: CGSize = .zero

        // §10.4: flying into the card, from full to the day's phase.
        if let flight = flight(at: date) {
            geometry = AhaFlight.geometry(landingOn: flight.glyph, progress: flight.progress)
            look.opacity = AhaFlight.interpolate(look.opacity, AhaFlight.landingGlowOpacity, flight.progress)
            // Drawn before the shrink, so it lands as the card's glow.
            let landingBlur = PhaseGlyph.cardGlowCSSBlur * moonFrame.width / flight.landingWidth
            glowBlur += (landingBlur - glowBlur) * flight.progress
            glyphGlow = AhaFlight.interpolate(glyphGlow, PhaseGlyph.cardGlowOpacity, flight.progress)
            // Lands on the card's own disc colour, so the card glyph takes over with no swap.
            discColor = discColor.mix(with: Theme.Colors.surface, by: flight.progress)
            scale = flight.frame.width / moonFrame.width
            offset = CGSize(width: flight.frame.midX - moonFrame.midX, height: flight.frame.midY - moonFrame.midY)
        }

        return PhaseGlyph(geometry: geometry, discColor: discColor, glowCSSBlur: glowBlur, glowOpacity: glyphGlow)
            .background {
                // Behind the glyph and outside layout, so it never moves the text.
                glow(size: size)
                    .opacity(look.opacity)
                    .scaleEffect(reduceMotion ? 1 : look.scale)
            }
            .scaleEffect(scale)
            .offset(offset)
    }

    /// Where the flight is at `date`, once it has somewhere to land.
    private func flight(
        at date: Date
    ) -> (progress: Double, frame: CGRect, landingWidth: CGFloat, glyph: PhaseGlyphGeometry)? {
        guard let start = loader.flightStartedAt, let landingSlot, let landingGlyph,
              moonFrame.width > 0, landingSlot.width > 0 else {
            return nil
        }
        let progress = AhaFlight.progress(since: start, at: date)
        let frame = AhaFlight.frame(from: moonFrame, to: landingSlot, progress: progress)
        return (progress, frame, landingSlot.width, landingGlyph)
    }

    private func glow(size: CGFloat) -> some View {
        let diameter = size * Self.glowDiameterPerMoon
        return Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.Colors.accent.opacity(Self.glowOpacity), Theme.Colors.accent.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }

    // MARK: - Message layout

    private enum MessageLayout {
        case regular
        case compact
        case scroll
    }

    /// Uses the natural height of the current message at the current Dynamic
    /// Type size. Compact buys room by shrinking and lifting the moon and by
    /// stepping the headline/body down together; scrolling is the final AX
    /// fallback, so no copy or action is clipped.
    private func messageLayout(
        screenHeight: CGFloat,
        safeAreaTop: CGFloat,
        bottomInset: CGFloat
    ) -> MessageLayout {
        guard case .message = loader.content, regularMessageHeight > 0 else { return .regular }

        let regularTop = screenHeight / 2 - Self.moonCentreAboveScreenCentre
            - Self.moonSize / 2 - safeAreaTop
        let regularRoom = screenHeight - safeAreaTop - regularTop - Self.moonSize
            - Self.moonToMessage - bottomInset
        if regularMessageHeight <= regularRoom { return .regular }

        guard compactMessageHeight > 0 else { return .compact }
        let compactTop = screenHeight / 2 - Self.moonCentreAboveScreenCentre
            - Self.compactMoonSize / 2 - safeAreaTop - Self.compactMoonRise
        let compactRoom = screenHeight - safeAreaTop - compactTop - Self.compactMoonSize
            - Self.moonToMessage - bottomInset
        return compactMessageHeight <= compactRoom ? .compact : .scroll
    }

    @ViewBuilder
    private func message(_ issue: LocationIssue, layout: MessageLayout, bottomInset: CGFloat) -> some View {
        let scale = layout == .regular ? 1 : Self.compactTextScale

        LoaderMessageIn {
            if layout == .scroll {
                ScrollView {
                    LoaderMessage(
                        issue: issue,
                        textScale: scale,
                        fillsHeight: false,
                        onPrimary: { primary(issue) },
                        onSearch: onSearch
                    )
                }
                .scrollIndicators(.hidden)
            } else {
                LoaderMessage(
                    issue: issue,
                    textScale: scale,
                    onPrimary: { primary(issue) },
                    onSearch: onSearch
                )
            }
        }
        .id(issue)
        .padding(.top, Self.moonToMessage)
        .padding(.horizontal, Theme.Metrics.onboardingMargin)
        .padding(.bottom, bottomInset)
    }

    /// Off-layout copies report their ideal heights without affecting the
    /// visible hierarchy or accessibility tree.
    private func messageMeasurements(_ issue: LocationIssue) -> some View {
        ZStack {
            measuredMessage(issue, scale: 1) { regularMessageHeight = $0 }
            measuredMessage(issue, scale: Self.compactTextScale) { compactMessageHeight = $0 }
        }
        .padding(.horizontal, Theme.Metrics.onboardingMargin)
        .hidden()
        .accessibilityHidden(true)
    }

    private func measuredMessage(
        _ issue: LocationIssue,
        scale: CGFloat,
        update: @escaping (CGFloat) -> Void
    ) -> some View {
        LoaderMessage(
            issue: issue,
            textScale: scale,
            fillsHeight: false,
            onPrimary: {},
            onSearch: {}
        )
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            update(height)
        }
    }

    // MARK: - Label

    private var label: some View {
        Text(Self.message)
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(labelIsIn ? 1 : 0)
            .offset(y: labelHasRisen || reduceMotion ? 0 : Self.entranceRise)
            .accessibilityHidden(!loader.showsLabel)
    }

    // MARK: - Actions

    private func primary(_ issue: LocationIssue) {
        guard issue.primaryAction == .openSettings else {
            onPrimary()
            return
        }
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    // MARK: - Motion

    private func enter() {
        withAnimation(.easeOut(duration: reduceMotion ? Self.reduceMotionFade : Self.moonFadeDuration)) {
            moonIsIn = true
        }
        if !reduceMotion {
            withAnimation(LoaderMotion.rise(duration: Self.moonRiseDuration)) { moonHasRisen = true }
        }
        // The label's first arrival follows the moon's; later ones (back
        // from a message) come in as soon as the loader says.
        showLabel(loader.showsLabel, delay: LocationLoader.labelEntranceDelay)
    }

    /// In: the entrance's fade and rise. Out: a 0.3 s fade, in place.
    private func showLabel(_ shows: Bool, delay: TimeInterval = 0) {
        guard shows else {
            withAnimation(.easeOut(duration: Self.labelOutDuration)) { labelIsIn = false }
            labelHasRisen = false
            return
        }
        if reduceMotion {
            withAnimation(.easeOut(duration: Self.reduceMotionFade).delay(delay)) { labelIsIn = true }
            return
        }
        withAnimation(.easeOut(duration: Self.labelFadeDuration).delay(delay)) { labelIsIn = true }
        withAnimation(LoaderMotion.rise(duration: Self.labelRiseDuration).delay(delay)) { labelHasRisen = true }
    }
}

// MARK: - Motion curves

/// The handoff's curves, shared by the loader's pieces.
enum LoaderMotion {
    /// `cubic-bezier(.16, 1, .3, 1)`: the entrance's rise.
    static func rise(duration: TimeInterval) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }

    /// `cubic-bezier(.2, .7, .3, 1)`: the message's rise.
    static func messageRise(duration: TimeInterval) -> Animation {
        .timingCurve(0.2, 0.7, 0.3, 1, duration: duration)
    }
}

// MARK: - Aha in and out

/// "Search → Aha" (§10.4): "Aha" fades in over 0.6 s after 0.5 s and rises
/// 10 pt over 0.8 s; when the moon flies it fades out fast, 0.22 s, drifting
/// up 3 pt. Reduce Motion: 0.3 s cross-fades, no rise or drift.
private struct AhaGreetingIn<Content: View>: View {

    let leaving: Bool
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIn = false
    @State private var hasRisen = false

    private static var rise: CGFloat { 10 }
    private static var delay: TimeInterval { 0.5 }
    private static var fadeDuration: TimeInterval { 0.6 }
    private static var riseDuration: TimeInterval { 0.8 }
    private static var leaveDrift: CGFloat { 3 }
    private static var leaveDuration: TimeInterval { 0.22 }
    private static var reduceMotionFade: TimeInterval { 0.3 }

    var body: some View {
        content
            .opacity(isIn && !leaving ? 1 : 0)
            .offset(y: yOffset)
            .onAppear {
                if reduceMotion {
                    withAnimation(.easeOut(duration: Self.reduceMotionFade)) { isIn = true }
                    return
                }
                withAnimation(.easeOut(duration: Self.fadeDuration).delay(Self.delay)) { isIn = true }
                withAnimation(LoaderMotion.rise(duration: Self.riseDuration).delay(Self.delay)) { hasRisen = true }
            }
            .animation(.easeOut(duration: reduceMotion ? Self.reduceMotionFade : Self.leaveDuration), value: leaving)
    }

    private var yOffset: CGFloat {
        if reduceMotion { return 0 }
        if leaving { return -Self.leaveDrift }
        return hasRisen ? 0 : Self.rise
    }
}

// MARK: - Message in

/// "Search → message" (§10.3): the message fades in over 0.45 s after
/// 0.35 s and rises 16 pt over 0.6 s. It leaves at once (the return is
/// "gone instantly"). Reduce Motion: a 0.3 s cross-fade, no rise.
private struct LoaderMessageIn<Content: View>: View {

    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIn = false
    @State private var hasRisen = false

    private static var rise: CGFloat { 16 }
    private static var delay: TimeInterval { 0.35 }
    private static var fadeDuration: TimeInterval { 0.45 }
    private static var riseDuration: TimeInterval { 0.6 }
    private static var reduceMotionFade: TimeInterval { 0.3 }

    var body: some View {
        content
            .opacity(isIn ? 1 : 0)
            .offset(y: hasRisen || reduceMotion ? 0 : Self.rise)
            .onAppear {
                if reduceMotion {
                    withAnimation(.easeOut(duration: Self.reduceMotionFade)) { isIn = true }
                    return
                }
                withAnimation(.easeOut(duration: Self.fadeDuration).delay(Self.delay)) { isIn = true }
                withAnimation(LoaderMotion.messageRise(duration: Self.riseDuration).delay(Self.delay)) {
                    hasRisen = true
                }
            }
    }
}

#Preview {
    let loader = LocationLoader()
    LaunchPhaseCycle(loader: loader, onPrimary: {}, onSearch: {})
        .background { ScreenBackground() }
        .onAppear { loader.appear() }
}
