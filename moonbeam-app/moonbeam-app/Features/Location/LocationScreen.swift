//
//  LocationScreen.swift
//  moonbeam-app
//

import os
import SwiftUI
import UIKit

/// Picks the place, then shows its moon table (LOCATION.md §3).
///
/// Being restyled to Design 1.1 step by step (DESIGN-1.1.md §7): the madlib
/// sentence and moon card are done; the compass follows in 5.4. All
/// decisions live in `LocationViewModel`, including which sheet opens after
/// another has finished closing.
struct LocationScreen: View {

    @Bindable var viewModel: LocationViewModel

    /// Back from the `noCity` state to the onboarding upsell
    /// (ONBOARDING-MOD-MAIN.md flow 3). Offered only while the view model
    /// says no city is set; `nil` hides it.
    var onReturnToOnboarding: (() -> Void)? = nil

    /// The declined screen's moon, in global coordinates, for Got it's moon
    /// entry to fly up from (STEP-5.14 §6.3).
    var moonEntryStartFrame: CGRect? = nil

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bottomBarAnimation = Animation.easeInOut(duration: 0.3)
    /// The Back swipe: it starts this close to the leading edge and travels
    /// at least this far, like the system's edge swipe.
    private static let backSwipeEdgeWidth: CGFloat = 24
    private static let backSwipeMinimumTravel: CGFloat = 80
    /// The `noCity` headline fills at most this share of the height between
    /// the Back chevron and the CTA, leaving air above and below it.
    private static let noCityHeadlineHeightFraction: CGFloat = 0.8
    private static let scrollToCompassAnimation = Animation.easeInOut(duration: 0.4)
    /// The compass block's scroll target for the pinned bar's Compass ↓.
    private static let compassScrollID = "compass"
    /// `nonisolated` so `.onGeometryChange`'s Sendable transform can read it.
    nonisolated private static let contentSpace = "locationContent"
    /// Keep short states scrollable across the prompt/row transition.
    private static let minimumScrollOverflow: CGFloat = 1
    @State private var scrollViewportHeight: CGFloat = 0

    /// For the pinned bar's rule (COMPASS-1.1.md §9.6), both in global
    /// coordinates: the dial's centre, and the fold (the bottom of the
    /// visible content: the screen's, or the bottom bar's top).
    @State private var dialCentreY: CGFloat?
    @State private var foldY: CGFloat?
    /// The pinned summary is redundant while the compass's own readout is
    /// still in the viewport, and at AX sizes the overlay can cover it.
    @State private var compassReadoutTopY: CGFloat?

    /// What sizes the dial to the screen's height (`CompassDial.faceDiameter`):
    /// the visible height (screen less the system's safe areas, so the same
    /// whether or not a bottom note shows), and where the compass starts in
    /// the content, below the status bar gap.
    @State private var viewportHeight: CGFloat?
    @State private var compassTopInContent: CGFloat?

    /// LOADER.md §2.1, Reduce Motion included (opacity only): the phase
    /// cycle fades in, and fades out faster as the content loads in.
    /// §11.2.7 (proposed): a light tap as the moon lands in the card.
    private static let landingHapticIntensity = 0.6

    private static func launchStageAnimation(
        to stage: LaunchStage,
        showingFailure: Bool,
        afterMoonEntry: Bool
    ) -> Animation {
        let readyDuration = if showingFailure {
            ContentLoadIn.duration
        } else if afterMoonEntry {
            MoonEntry.exitFadeDuration
        } else {
            LaunchStage.phaseCycleFadeOutDuration
        }
        return .easeOut(duration: stage == .ready ? readyDuration : LaunchStage.fadeDuration)
    }

    var body: some View {
        // LOADER.md: while the launch fetch runs, plain background and then
        // the phase cycle. The real screen (with its compass and pinned bar)
        // isn't built until it's ready.
        ZStack {
            switch viewModel.launchStage {
            case .waiting, .phaseCycle:
                Color.clear
            case .ready:
                if let failure = viewModel.failureScreen {
                    // STEP-5.10a Chunk 3: in place of the main content, so
                    // no sentence, card, compass or DEBUG buttons. Its
                    // entrance is Chunk 6's.
                    LocationFailureView(
                        failure: failure,
                        onSearch: viewModel.presentSearch,
                        searchAvailable: viewModel.offersCitySearch
                    )
                    .environment(\.failureFollowsLoader, viewModel.failureFollowsLoader)
                    .transition(.identity)
                } else {
                    // §2.1: no whole-screen fade. The screen arrives at once
                    // and its blocks load in (`ContentLoadIn`). Under "Aha"'s
                    // flying moon they're timed around the flight, and the
                    // card's glyph waits for the moon (§10.4, §11.2.6).
                    ScrollViewReader { scrollProxy in
                        scrollView(scrollProxy)
                    }
                    .modifier(BackToOnboarding(
                        isEnabled: showsBackToOnboarding,
                        edgeWidth: Self.backSwipeEdgeWidth,
                        minimumTravel: Self.backSwipeMinimumTravel,
                        action: returnToOnboarding
                    ))
                    .environment(\.contentArrivesAfterAha, isAhaFlying)
                    .environment(\.hidesCardPhaseGlyph, isAhaFlying)
                    .transition(.identity)
                }
            }
        }
        // The loader sits over the screen, so it can stay up while "Aha"'s
        // moon flies into the card's phase slot, reported from below.
        .overlayPreferenceValue(CardPhaseSlotKey.self) { slot in
            GeometryReader { proxy in
                if viewModel.launchStage == .phaseCycle || isAhaFlying {
                    // §10.2: the loader brings its own entrance, so it only
                    // fades on the way out.
                    LaunchPhaseCycle(
                        loader: viewModel.loader,
                        onPrimary: { Task { await viewModel.performLoaderAction() } },
                        onSearch: viewModel.presentSearch,
                        searchAvailable: viewModel.offersCitySearch,
                        landingSlot: slot.map { globalFrame(of: $0, in: proxy) },
                        landingGlyph: viewModel.moonTable?.glyph,
                        entryStartFrame: moonEntryStartFrame
                    )
                    .allowsHitTesting(!isAhaFlying)
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                    .onAppear(perform: announcePhaseCycle)
                }
            }
        }
        .animation(
            Self.launchStageAnimation(
                to: viewModel.launchStage,
                showingFailure: viewModel.failureScreen != nil,
                afterMoonEntry: viewModel.loader.entryStartedAt != nil
            ),
            value: viewModel.launchStage
        )
        // §10.4: the moon has landed (or, with Reduce Motion, the
        // cross-fade to the screen has ended) and the card's own glyph takes
        // over, with a light tap (§11.2.7).
        .task(id: viewModel.loader.flightStartedAt) {
            guard viewModel.loader.flightStartedAt != nil else { return }
            let wait = reduceMotion ? LaunchStage.phaseCycleFadeOutDuration : LocationLoader.flightDuration
            try? await Task.sleep(for: .seconds(wait))
            viewModel.loader.didLand()
        }
        // Softer than the compass lock's heavy tap, so the two feel
        // different; follows the System Haptics setting.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: Self.landingHapticIntensity), trigger: viewModel.loader.landingCount)
        .onChange(of: viewModel.launchStage) { old, new in
            // §4: focus leaves the vanished loader text for the screen's
            // first element, the sentence header.
            if old == .phaseCycle, new == .ready {
                AccessibilityNotification.ScreenChanged().post()
            }
        }
        .background { ScreenBackground() }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            viewportHeight = height
        }
        .onAppear {
            LaunchSignposts.signposter.emitEvent("LocationScreen.onAppear")
        }
        .task {
            await viewModel.start()
        }
        // Chunk 2c: the network is watched only while a search action can
        // show; the task ends, and with it the monitor, when it can't.
        .task(id: viewModel.showsSearchAction) {
            guard viewModel.showsSearchAction else { return }
            await viewModel.observeConnectivity()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await viewModel.sceneDidBecomeActive() }
            case .background:
                viewModel.sceneDidEnterBackground()
            default:
                // Inactive (Control Center, the permission prompt) keeps the
                // compass running; only the background stops it (§1).
                break
            }
        }
        .sheet(item: $viewModel.locationOffDialog, onDismiss: viewModel.locationOffDialogDidDismiss) { variant in
            LocationOffDialog(
                variant: variant,
                onSearch: viewModel.searchInsteadOfLocation,
                onOpenedSettings: viewModel.dismissLocationOffDialog
            )
        }
        .sheet(isPresented: $viewModel.isSearchPresented, onDismiss: searchDidDismiss) {
            if let searchSheet = viewModel.searchSheet {
                SearchSheet(viewModel: searchSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $viewModel.isCalendarPresented) {
            CalendarSheet(viewModel: viewModel, maximumHeight: viewportHeight ?? 0)
        }
    }

    private func scrollView(_ scrollProxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // DESIGN-1.1.md §3.1: the sentence is the header; its tokens
                // open the calendar and the search sheet.
                // ONBOARDING-MOD-MAIN.md: on `noCity` the same sentence
                // grows to fill the screen and sits centred between the Back
                // chevron and the CTA; the empty card and the debug panel
                // follow below the fold, so they can't move it. A minimum,
                // not a fixed height, so AX sizes scroll instead of clipping.
                MadlibSentence(viewModel: viewModel, fillHeight: noCityHeadlineFillHeight)
                    .frame(minHeight: noCityHeadlineRegionHeight, alignment: .leading)
                    // LOADER.md §12.9: loads in with the screen only; a
                    // place change cross-fades its city token in place.
                    .contentLoadIn(.sentence)

                // Location status stays with the card, under the sentence
                // whose place token it's about. The no-place screen and its
                // Use my location button are gone (LOADER.md §10): the way
                // back to your location is the search sheet's row.
                // 5.10a.13: the card layer loads in like a searched city's
                // card; the skeleton or failure layer sits over it, outside
                // that load-in, and fades out as the card arrives.
                ZStack(alignment: .top) {
                    PlaceCardRegion(viewModel: viewModel, layer: .card)
                        .contentLoadIn(.card, generation: viewModel.cardLoadInGeneration)
                    PlaceCardRegion(viewModel: viewModel, layer: .placeholder)
                }
                .padding(.top, Theme.Metrics.sentenceToCard)

                // A stack that's always there, so the load-in runs once when
                // the screen arrives, not again when the compass comes later.
                VStack(alignment: .leading, spacing: 0) {
                    // COMPASS.md §1: at the bottom, below the moon card.
                    if !viewModel.isReplacingPlace, viewModel.compass.visibility != .hidden {
                        compass
                            .id(Self.compassScrollID)
                            .padding(.top, Theme.Metrics.cardToCompass)
                    }

                }
                // Held out while a replacement is pending, so nothing in it
                // shows under an empty slot.
                .contentLoadIn(
                    .compass,
                    generation: viewModel.loadInGeneration,
                    isActive: !viewModel.isReplacingPlace
                )
            }
            // Where the compass starts, measured in the content's own space so
            // scrolling doesn't change it (the dial's height budget).
            .coordinateSpace(.named(Self.contentSpace))
            .padding(.horizontal, Theme.Metrics.screenMargin)
            .padding(.top, Theme.Metrics.contentTopSpacing)
            .padding(.bottom, Theme.Metrics.screenMargin)
            // A minimum preserves the short prompt/row transition's scroll
            // model without fixing the content extent to one screen. At AX
            // sizes the full stack must contribute its natural height.
            .frame(minHeight: scrollViewportHeight + Self.minimumScrollOverflow, alignment: .top)
        }
        // Child cards animate their own height. Preserve the reader's exact
        // offset while layout changes so content above a card doesn't move.
        .transaction { transaction in
            transaction.scrollContentOffsetAdjustmentBehavior = .disabled
        }
        .scrollBounceBehavior(.basedOnSize)
        // COMPASS-1.1.md §9.6: over the content, not an inset, so it doesn't
        // move the fold it's shown for. Inside the bottom bar's inset, so it
        // sits on top of the note.
        .overlay(alignment: .bottom) {
            if viewModel.compass.showsPinnedBar {
                CompassPinnedBar(viewModel: viewModel.compass) {
                    withAnimation(reduceMotion ? nil : Self.scrollToCompassAnimation) {
                        scrollProxy.scrollTo(Self.compassScrollID, anchor: .top)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : Self.bottomBarAnimation, value: viewModel.compass.showsPinnedBar)
        // The fold: the scroll view's frame already stops at the home
        // indicator, or at the bottom bar's top when a note shows (its
        // safe-area inset); subtracting the insets again counted them twice.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            foldY = frame.maxY
            scrollViewportHeight = frame.height
            updatePinnedBar()
        }
        // COMPASS-1.1.md §9.4: the compass's note in a bar fixed above the
        // home indicator. An inset, so the content scrolls above it and the
        // top of the screen doesn't move when it comes and goes.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The compass's note loads in with the compass (§2.1); the stack
            // is always there, so a note arriving later only slides in.
            VStack(spacing: 0) {
                // ONBOARDING-MOD-MAIN.md: the `noCity` CTA and "Start with",
                // fading out as a city fills in.
                if viewModel.isNoCity {
                    NoCityActions(
                        action: viewModel.noCityAction,
                        startCity: viewModel.noCityStartCity,
                        onEnableLocation: { Task { await viewModel.enableLocationFromNoCity() } },
                        onOpenSettings: openSettings,
                        onStartWithCity: viewModel.startWithSuggestedCity
                    )
                    .contentLoadIn(index: 1)
                    .transition(.opacity)
                }
                if let note = viewModel.compass.bottomNote {
                    CompassBottomBar(note: note) {
                        Task { await viewModel.usePreciseLocationForCompass() }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentLoadIn(
                .compass,
                generation: viewModel.loadInGeneration,
                isActive: !viewModel.isReplacingPlace
            )
        }
        .animation(reduceMotion ? nil : Self.bottomBarAnimation, value: viewModel.compass.bottomNote)
        .animation(reduceMotion ? nil : Self.bottomBarAnimation, value: viewModel.isNoCity)
        .animation(reduceMotion ? nil : Self.bottomBarAnimation, value: viewModel.noCityAction)
        // STEP-5.15: over the content so the headline fades under the status
        // bar; under the Back chevron's inset so it never dims the chevron.
        .statusBarScrim()
        // Back to the upsell while no city is set (ONBOARDING-MOD-MAIN.md).
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsBackToOnboarding {
                Button(action: returnToOnboarding) {
                    Image(systemName: "chevron.left")
                        .font(Theme.Fonts.body)
                }
                .buttonStyle(.inline(Theme.Colors.accent))
                .accessibilityLabel(OnboardingCopy.back)
                .accessibilityHint(OnboardingCopy.backHint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Metrics.screenMargin)
                .transition(.opacity)
            }
        }
        // Keep the native soft scroll edge treatment, while the shared
        // ScreenBackground remains visible behind the status bar.
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    // MARK: - Compass

    /// The fraction of the compass that must be visible for its sensors to
    /// run: a sliver counts (COMPASS.md §1 "on screen" = any part visible).
    private static let compassVisibilityThreshold = 0.1

    /// Reports whether the compass is on screen, which (with foreground and
    /// visibility) decides whether its sensors run (COMPASS.md §1).
    ///
    /// The stack isn't lazy, so `onAppear` fires on insertion even when the
    /// compass is below the fold. It isn't used for "on screen", or the
    /// sensors would start off screen. `onScrollVisibilityChange` also fires
    /// on appearing when already past its threshold, which covers insertion.
    /// `onDisappear` covers removal.
    ///
    /// "On screen" is any part visible (DECISIONS.md 2026-10-02): with the
    /// default half-visible threshold, a dial peeking above the fold stayed
    /// greyed with its sensors off.
    private var compass: some View {
        CompassView(
            viewModel: viewModel.compass,
            heightBudget: compassHeightBudget,
            onTurnOnLocation: { Task { await viewModel.turnOnLocationForCompass() } },
            onDialCentreChange: { centreY in
                dialCentreY = centreY
                updatePinnedBar()
            },
            onReadoutTopChange: { topY in
                compassReadoutTopY = topY
                updatePinnedBar()
            }
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named(Self.contentSpace)).minY
        } action: { minY in
            // Whole points, so a sub-point wobble can't resize the dial.
            compassTopInContent = minY.rounded()
        }
        .onScrollVisibilityChange(threshold: Self.compassVisibilityThreshold) { isVisible in
            viewModel.compass.setOnScreen(isVisible)
        }
        .onDisappear {
            viewModel.compass.setOnScreen(false)
            dialCentreY = nil
            compassReadoutTopY = nil
            updatePinnedBar()
        }
    }

    /// The height from the compass's top to the bottom of the screen, less
    /// the breathing room kept under it (`CompassDial.bottomPaddingFraction`
    /// of the screen's height). `nil` until both are measured: the dial is
    /// then sized by the width alone.
    private var compassHeightBudget: CGFloat? {
        guard let viewportHeight, let compassTopInContent else { return nil }
        let top = Theme.Metrics.contentTopSpacing + compassTopInContent
        return CompassDial.heightBudget(viewportHeight: viewportHeight, compassTop: top)
    }

    /// Tells the compass whether its dial's centre is below the fold
    /// (COMPASS-1.1.md §9.6). No dial, no bar.
    private func updatePinnedBar() {
        guard let dialCentreY, let compassReadoutTopY, let foldY else {
            viewModel.compass.setDialCentreBelowFold(false)
            return
        }
        viewModel.compass.setDialCentreBelowFold(
            Self.shouldShowPinnedBar(
                dialCentreY: dialCentreY,
                readoutTopY: compassReadoutTopY,
                foldY: foldY
            )
        )
    }

    /// The existing centre rule plus the 5.5 de-duplication gate: while the
    /// screen's full readout is visible, the pinned copy stays out of its way.
    static func shouldShowPinnedBar(dialCentreY: CGFloat, readoutTopY: CGFloat, foldY: CGFloat) -> Bool {
        CompassViewModel.isBelowFold(dialCentreY: dialCentreY, foldY: foldY)
            && readoutTopY >= foldY
    }

    // MARK: - Aha (LOADER.md §10.4)

    /// The loader's moon is flying into the card. Reduce Motion: no fly,
    /// the loader just fades.
    private var isAhaFlying: Bool {
        viewModel.loader.flightStartedAt != nil && !reduceMotion
    }

    private func globalFrame(of anchor: Anchor<CGRect>, in proxy: GeometryProxy) -> CGRect {
        let origin = proxy.frame(in: .global).origin
        return proxy[anchor].offsetBy(dx: origin.x, dy: origin.y)
    }

    // MARK: - Actions

    /// §4: "Finding your location", once per launch.
    private func announcePhaseCycle() {
        if let announcement = viewModel.phaseCycleDidAppear() {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private func searchDidDismiss() {
        Task { await viewModel.searchDidDismiss() }
    }

    // MARK: - No city (ONBOARDING-MOD-MAIN.md)

    /// The visible height the `noCity` headline is centred in: the scroll
    /// view's frame (already inside the chevron and CTA insets) less the gap
    /// under the status bar. `nil` once a city is set.
    private var noCityHeadlineRegionHeight: CGFloat? {
        guard viewModel.isNoCity else { return nil }
        return max(0, scrollViewportHeight - Theme.Metrics.contentTopSpacing)
    }

    private var noCityHeadlineFillHeight: CGFloat? {
        noCityHeadlineRegionHeight.map { $0 * Self.noCityHeadlineHeightFraction }
    }

    private var showsBackToOnboarding: Bool {
        viewModel.canReturnToOnboarding && onReturnToOnboarding != nil
    }

    private func returnToOnboarding() {
        guard showsBackToOnboarding else { return }
        onReturnToOnboarding?()
    }

    /// The `noCity` CTA's Open Settings: the app's own page. The view model
    /// checks again on the way back.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Back to onboarding

/// The `noCity` state's Back by swipe from the leading edge, and VoiceOver's
/// escape gesture. The chevron is the visible way; this screen has no
/// navigation stack, so the system swipe isn't there to borrow.
private struct BackToOnboarding: ViewModifier {

    let isEnabled: Bool
    let edgeWidth: CGFloat
    let minimumTravel: CGFloat
    let action: () -> Void

    /// No `if`/`else` on `isEnabled`: that would swap the screen's identity
    /// as a city lands and reset its scroll and load-ins.
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture().onEnded { drag in
                    guard drag.startLocation.x <= edgeWidth,
                          drag.translation.width >= minimumTravel else { return }
                    action()
                },
                including: isEnabled ? .all : .none
            )
            .accessibilityAction(.escape) {
                guard isEnabled else { return }
                action()
            }
    }
}

#Preview("First launch") {
    LocationScreen(
        viewModel: LocationViewModel(
            locationService: FakeLocationService(),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService()
        )
    )
}

#Preview("Denied, saved place") {
    LocationScreen(
        viewModel: LocationViewModel(
            locationService: FakeLocationService(authorizationState: .denied),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(lastViewed: Place.marVista),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService()
        )
    )
}
