//
//  CompassEntranceFrameTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// STEP-5.10a.3, Tessa's launch recording (Irvine, 2026-10-12): sample the
/// real `CompassView` every 16 ms as its sensors start and the first
/// headings arrive (179° → 185° → 190°, as on the phone), as 5.10b sampled
/// the day arrows.
///
/// Against the launch bug it fails three ways: the dial shows north-up
/// before the first heading (N's amber at 12 o'clock), the letters and
/// targets collapse to the centre as the first heading lerps every
/// `.position` in a straight line, and the readout shows 179° and counts.
@Suite("Compass entrance frames", .timeLimit(.minutes(1)))
@MainActor
struct CompassEntranceFrameTests {

    // MARK: - Fixtures

    private static let windowSize = CGSize(width: 402, height: 874)
    private static let headings = [179.0, 185.0, 190.0]
    private static let finalReadout = "190°"
    /// Samples at which each of `headings` is sent: about 50, 130 and 210 ms
    /// in, inside the entrance, as on the phone.
    private static let headingSamples = [3, 8, 13]
    private static let sampleInterval = Duration.milliseconds(16)
    /// Past the 0.5 s settle and the readout's fade, with capture overhead.
    private static let sampleCount = 70
    private static let layoutWait = Duration.milliseconds(400)

    /// `CompassDial`'s letter distance on its 196 pt design dial (private
    /// there): N/E/S/W sit this far from the centre.
    private static let letterCentreDistance: CGFloat = 58
    /// "Inside the centre radius": half the letters' distance, where no
    /// letter or target ever is while the dial turns as one piece.
    private static let centreRadiusShare: CGFloat = 0.5
    /// Half a letter's box, on the design dial.
    private static let letterHalfBox: CGFloat = 12
    /// How far left of 12 o'clock to look for S at 190°, as a share of the
    /// letters' distance.
    private static let southSideShare: CGFloat = 0.2

    /// Light text: every channel above any face, tick or crosshair colour
    /// (the brightest of those, `tick`, is 0x807075).
    private static let inkChannelMinimum: UInt8 = 150
    /// Amber (`accent` 0xF2C27B, even at the no-heading look's 40%): red
    /// well above blue. Cream text and the face are not.
    private static let amberRedOverBlue = 35
    private static let amberRedMinimum: UInt8 = 90
    /// A letter is hundreds of pixels; anti-aliasing and the centre dot a
    /// handful.
    private static let markPixelMinimum = 20

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)

    private static let place = Place(
        name: "Irvine",
        region: "CA",
        latitude: Place.irvine.latitude,
        longitude: Place.irvine.longitude,
        timeZone: losAngelesZone,
        isCurrentLocation: true
    )

    private static let context = CompassContext(
        place: place,
        detectedPlace: place,
        authState: .authorized,
        moonDay: MoonDay(
            place: place,
            rise: MoonEvent(date: referenceDate, azimuth: 72),
            set: MoonEvent(date: referenceDate, azimuth: 288),
            phase: .full,
            phaseAngle: FakeMoonService.fullMoonPhaseAngle,
            illumination: FakeMoonService.fullyLit
        ),
        isToday: true
    )

    // MARK: - Test

    @Test("Launch entrance: never north-up, nothing in the centre, no stale readout", .timeLimit(.minutes(1)))
    func launchEntranceFrames() async throws {
        let heading = FakeHeadingService()
        let viewModel = CompassViewModel(
            headingService: heading,
            moonService: FakeMoonService(position: MoonPosition(azimuth: 140, altitude: 23, isUp: true)),
            now: { Self.referenceDate }
        )
        viewModel.update(Self.context)

        let probe = CompassFrameProbe()
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.windowSize)
        window.rootViewController = UIHostingController(
            rootView: CompassFrameHarness(viewModel: viewModel, probe: probe)
        )
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            viewModel.setOnScreen(false)
        }
        try await Task.sleep(for: Self.layoutWait)

        let centreY = try #require(probe.dialCentreY, "the dial never reported its centre")
        let centre = CGPoint(x: Self.windowSize.width / 2, y: centreY)
        let width = Self.windowSize.width - 2 * Theme.Metrics.screenMargin
        let scale = CompassDial.faceDiameter(forWidth: width) / CompassDial.designDiameter
        let letterDistance = Self.letterCentreDistance * scale
        let centreRadius = letterDistance * Self.centreRadiusShare
        let half = Self.letterHalfBox * scale
        let northUpN = CGRect(x: centre.x - half, y: centre.y - letterDistance - half, width: 2 * half, height: 2 * half)

        // The launch: sensors start with no heading yet.
        viewModel.setOnScreen(true)
        var sentIndex = 0
        for sample in 0..<Self.sampleCount {
            if sentIndex < Self.headings.count, sample == Self.headingSamples[sentIndex] {
                heading.send(HeadingReading(trueHeading: Self.headings[sentIndex], accuracy: 3))
                sentIndex += 1
            }
            let frame = try #require(Self.capture(window))

            let amber = Self.count(in: frame, rect: northUpN, where: Self.isAmber)
            #expect(amber < Self.markPixelMinimum, "north-up at sample \(sample): \(amber) amber px where N sits north-up")

            let centreInk = Self.count(in: frame, around: centre, radius: centreRadius, where: Self.isInk)
            #expect(centreInk < Self.markPixelMinimum, "marks in the centre at sample \(sample): \(centreInk) px")

            if viewModel.readoutOpacity > 0 {
                #expect(
                    viewModel.headingReadout?.lead == Self.finalReadout,
                    "readout showed \(viewModel.headingReadout?.lead ?? "nothing") at sample \(sample)"
                )
            }
            try await Task.sleep(for: Self.sampleInterval)
        }

        // Controls: the capture does see the dial. At 190° N is at the
        // bottom, amber, and S near the top, light.
        let last = try #require(Self.capture(window))
        // S is 10° left of 12 o'clock at 190°: sin 10° ≈ 0.17 of its distance.
        let southShift = letterDistance * Self.southSideShare
        let southUp = CGRect(x: centre.x - half - southShift, y: centre.y - letterDistance - half,
                             width: 2 * half + southShift, height: 2 * half)
        #expect(Self.count(in: last, rect: southUp, where: Self.isInk) >= Self.markPixelMinimum, "no S near the top at 190°")
        #expect(viewModel.entrance.phase == .settled)
        #expect(viewModel.readoutOpacity == 1)
        #expect(viewModel.headingReadout?.lead == Self.finalReadout)
    }

    // MARK: - Pixels

    private struct Frame {
        let image: CGImage
        let bytes: UnsafePointer<UInt8>
        let data: CFData
    }

    /// The window as currently drawn, animations included
    /// (`afterScreenUpdates: false`), 8 bits per channel at 1×.
    private static func capture(_ window: UIWindow) -> Frame? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        guard let cgImage = image.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        return Frame(image: cgImage, bytes: bytes, data: data)
    }

    private static func isInk(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Bool {
        red > inkChannelMinimum && green > inkChannelMinimum && blue > inkChannelMinimum
    }

    private static func isAmber(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Bool {
        red > amberRedMinimum && Int(red) - Int(blue) > amberRedOverBlue && red >= green
    }

    private static func count(in frame: Frame, rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> Int {
        count(in: frame, pixels: rect, include: { _, _ in true }, test: test)
    }

    private static func count(
        in frame: Frame,
        around centre: CGPoint,
        radius: CGFloat,
        where test: (UInt8, UInt8, UInt8) -> Bool
    ) -> Int {
        let box = CGRect(x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius)
        return count(
            in: frame,
            pixels: box,
            include: { x, y in hypot(x - centre.x, y - centre.y) <= radius },
            test: test
        )
    }

    private static func count(
        in frame: Frame,
        pixels rect: CGRect,
        include: (CGFloat, CGFloat) -> Bool,
        test: (UInt8, UInt8, UInt8) -> Bool
    ) -> Int {
        let image = frame.image
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height)).integral
        guard !bounds.isNull else { return 0 }
        let bytesPerPixel = image.bitsPerPixel / 8
        var count = 0
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) where include(CGFloat(x), CGFloat(y)) {
                let offset = y * image.bytesPerRow + x * bytesPerPixel
                if test(frame.bytes[offset], frame.bytes[offset + 1], frame.bytes[offset + 2]) {
                    count += 1
                }
            }
        }
        return count
    }
}

/// The dial's centre in the window.
@MainActor
private final class CompassFrameProbe {
    var dialCentreY: CGFloat?
}

/// The compass as on the main screen: full width less the margins, on the
/// screen's background, at the default text size.
@MainActor
private struct CompassFrameHarness: View {
    let viewModel: CompassViewModel
    let probe: CompassFrameProbe

    var body: some View {
        VStack(spacing: 0) {
            CompassView(
                viewModel: viewModel,
                onTurnOnLocation: {},
                onDialCentreChange: { probe.dialCentreY = $0 }
            )
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .padding(.top, Theme.Metrics.contentTopSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.bg)
        .environment(\.dynamicTypeSize, .large)
    }
}
