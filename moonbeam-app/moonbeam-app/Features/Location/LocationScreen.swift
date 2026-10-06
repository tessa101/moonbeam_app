//
//  LocationScreen.swift
//  moonbeam-app
//

import os
import SwiftUI

/// Picks the place, then shows its moon table (LOCATION.md §3).
///
/// Being restyled to Design 1.1 step by step (DESIGN-1.1.md §7): the madlib
/// sentence and moon card are done; the compass follows in 5.4. All
/// decisions live in `LocationViewModel`, including which sheet opens after
/// another has finished closing.
struct LocationScreen: View {

    @Bindable var viewModel: LocationViewModel

    /// The Show onboarding button (DECISIONS.md 2026-10-01): the forced
    /// onboarding flow. The app passes it in DEBUG and TestFlight builds
    /// only (`BuildChannel`); `nil` hides the button. Temporary.
    var onShowOnboarding: (() -> Void)? = nil

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bottomBarAnimation = Animation.easeInOut(duration: 0.3)
    private static let scrollToCompassAnimation = Animation.easeInOut(duration: 0.4)
    /// The compass block's scroll target for the pinned bar's Compass ↓.
    private static let compassScrollID = "compass"

    /// For the pinned bar's rule (COMPASS-1.1.md §9.6), both in global
    /// coordinates: the dial's centre, and the fold (the bottom of the
    /// visible content: the screen's, or the bottom bar's top).
    @State private var dialCentreY: CGFloat?
    @State private var foldY: CGFloat?

    /// LOADER.md §2.1, Reduce Motion included (opacity only): the phase
    /// cycle fades in, and fades out faster as the content loads in.
    private static func launchStageAnimation(to stage: LaunchStage) -> Animation {
        .easeOut(duration: stage == .ready ? LaunchStage.phaseCycleFadeOutDuration : LaunchStage.fadeDuration)
    }

    var body: some View {
        // LOADER.md: while the launch fetch runs, plain background and then
        // the phase cycle. The real screen (with its compass, pinned bar,
        // DEBUG readout and Show onboarding) isn't built until it's ready.
        ZStack {
            switch viewModel.launchStage {
            case .waiting:
                Color.clear
            case .phaseCycle:
                // §10.2: the loader brings its own entrance, so it only
                // fades on the way out.
                LaunchPhaseCycle(
                    loader: viewModel.loader,
                    onPrimary: { Task { await viewModel.performLoaderAction() } },
                    onSearch: viewModel.presentSearch
                )
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                    .onAppear(perform: announcePhaseCycle)
            case .ready:
                // §2.1: no whole-screen fade. The screen arrives at once and
                // its blocks load in (`ContentLoadIn`).
                ScrollViewReader { scrollProxy in
                    scrollView(scrollProxy)
                }
                .transition(.identity)
            }
        }
        .animation(Self.launchStageAnimation(to: viewModel.launchStage), value: viewModel.launchStage)
        .onChange(of: viewModel.launchStage) { old, new in
            // §4: focus leaves the vanished loader text for the screen's
            // first element, the sentence header.
            if old == .phaseCycle, new == .ready {
                AccessibilityNotification.ScreenChanged().post()
            }
        }
        .background { ScreenBackground() }
        .onAppear {
            LaunchSignposts.signposter.emitEvent("LocationScreen.onAppear")
        }
        .task {
            await viewModel.start()
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
            CalendarSheet(viewModel: viewModel)
        }
    }

    private func scrollView(_ scrollProxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // DESIGN-1.1.md §3.1: the sentence is the header; its tokens
                // open the calendar and the search sheet.
                MadlibSentence(viewModel: viewModel)
                    .contentLoadIn(.sentence)

                // Location status stays with the card, under the sentence
                // whose place token it's about. The no-place screen and its
                // Use my location button are gone (LOADER.md §10): the way
                // back to your location is the search sheet's row.
                VStack(alignment: .leading, spacing: Theme.Metrics.sentenceToCard) {
                    if viewModel.isLocating {
                        ProgressView("Finding your location…")
                    }

                    if viewModel.locationFailed {
                        Text("Couldn't find your location. Try again, or search for a city.")
                    }

                    // §3.2. The place's zone sits beside each time.
                    if let moonTable = viewModel.moonTable {
                        MoonCard(viewModel: viewModel, table: moonTable)
                    }
                }
                .padding(.top, Theme.Metrics.sentenceToCard)
                .contentLoadIn(.card)

                // A stack that's always there, so the load-in runs once when
                // the screen arrives, not again when the compass comes later.
                VStack(alignment: .leading, spacing: 0) {
                    // COMPASS.md §1: at the bottom, below the moon card. DEBUG
                    // builds keep it in every state for its diagnostic readout;
                    // the sensors still only run when it's shown.
                    if viewModel.compass.visibility != .hidden || Self.showsDebugReadout {
                        compass
                            .id(Self.compassScrollID)
                            .padding(.top, Theme.Metrics.cardToCompass)
                    }

                    // At the very bottom, under the compass (and its DEBUG
                    // readout): out of the design's way.
                    if let onShowOnboarding {
                        // The text-link style: amber, and a 44 pt target.
                        Button("Show onboarding", action: onShowOnboarding)
                            .buttonStyle(.textLink)
                            .padding(.top)
                    }
                }
                .contentLoadIn(.compass)
            }
            .padding(.horizontal, Theme.Metrics.screenMargin)
            .padding(.top, Theme.Metrics.contentTopSpacing)
            .padding(.bottom, Theme.Metrics.screenMargin)
        }
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
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).maxY
        } action: { fold in
            foldY = fold
            updatePinnedBar()
        }
        // COMPASS-1.1.md §9.4: the compass's note in a bar fixed above the
        // home indicator. An inset, so the content scrolls above it and the
        // top of the screen doesn't move when it comes and goes.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The compass's note loads in with the compass (§2.1); the stack
            // is always there, so a note arriving later only slides in.
            VStack(spacing: 0) {
                if let note = viewModel.compass.bottomNote {
                    CompassBottomBar(note: note) {
                        Task { await viewModel.usePreciseLocationForCompass() }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentLoadIn(.compass)
        }
        .animation(reduceMotion ? nil : Self.bottomBarAnimation, value: viewModel.compass.bottomNote)
        // 4.15: content mustn't slide under the clock unreadably. The
        // system's soft edge effect, as in system apps; styling is the
        // design pass.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .modifier(StatusBarBackdrop())
    }

    // MARK: - Compass

    /// The fraction of the compass that must be visible for its sensors to
    /// run: a sliver counts (COMPASS.md §1 "on screen" = any part visible).
    private static let compassVisibilityThreshold = 0.1

    #if DEBUG
    private static let showsDebugReadout = true
    #else
    private static let showsDebugReadout = false
    #endif

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
            onTurnOnLocation: { Task { await viewModel.turnOnLocationForCompass() } },
            onDialCentreChange: { centreY in
                dialCentreY = centreY
                updatePinnedBar()
            }
        )
        .onScrollVisibilityChange(threshold: Self.compassVisibilityThreshold) { isVisible in
            viewModel.compass.setOnScreen(isVisible)
        }
        .onDisappear {
            viewModel.compass.setOnScreen(false)
            dialCentreY = nil
            updatePinnedBar()
        }
    }

    /// Tells the compass whether its dial's centre is below the fold
    /// (COMPASS-1.1.md §9.6). No dial, no bar.
    private func updatePinnedBar() {
        guard let dialCentreY, let foldY else {
            viewModel.compass.setDialCentreBelowFold(false)
            return
        }
        viewModel.compass.setDialCentreBelowFold(CompassViewModel.isBelowFold(dialCentreY: dialCentreY, foldY: foldY))
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
}

// MARK: - Status bar (4.15)

/// The fallback for iOS 26 (DECISIONS.md 2026-09-30): the device test on
/// iOS 26.6.2 showed no edge effect at all for this bare `ScrollView` under
/// the status bar, so the date control sat crisp behind the clock. There the
/// status bar gets a solid `bg` backing, as in the design (DESIGN-1.1.md §2;
/// it replaced 4.15's system bar material). iOS 27 draws the soft edge effect
/// itself, so it's left alone.
private struct StatusBarBackdrop: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                // Zero height: the backing fills only the status bar, since
                // a background extends into the safe area it touches.
                Color.clear
                    .frame(height: 0)
                    .background(Theme.Colors.bg)
            }
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
