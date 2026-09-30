//
//  HeadingServiceTests.swift
//  moonbeam-appTests
//

import CoreLocation
import Foundation
import Testing
@testable import moonbeam_app

/// `HeadingReading`'s accuracy rules and the `HeadingService` session contract
/// (COMPASS.md §1 Accuracy and Sensor lifecycle, §6).
///
/// Live headings can't be tested: the simulator has no compass. What *is*
/// testable is the reading mapping, the fake that view-model tests will drive,
/// and `CoreLocationHeadingService`'s no-compass path, which is exactly what
/// the simulator exercises.
@Suite("Heading")
@MainActor
struct HeadingServiceTests {

    // MARK: - Constants

    /// Upper bound on main-actor turns to wait for a stream's
    /// `onTermination` hop to land. It lands in one or two; this only stops a
    /// broken implementation hanging the suite.
    private static let maxYieldsForTermination = 100

    // MARK: - Reading values
    //
    // Whether a reading counts as low accuracy is `CompassAccuracy`'s rule
    // (hysteresis), tested in `CompassAccuracyTests`.

    @Test("A reading keeps its heading and accuracy")
    func goodReading() {
        let reading = HeadingReading(trueHeading: 72, accuracy: 5)

        #expect(reading.trueHeading == 72)
        #expect(reading.accuracy == 5)
    }

    @Test("Unavailable has no heading and no accuracy")
    func unavailableHasNothing() {
        #expect(HeadingReading.unavailable.trueHeading == nil)
        #expect(HeadingReading.unavailable.accuracy == nil)
    }

    // MARK: - Reading: CoreLocation's raw values

    /// `CLHeading` reports an invalid `trueHeading` (location updates off) or
    /// `headingAccuracy` as a negative number.
    @Test("Negative raw values mean invalid")
    func negativeRawValuesAreInvalid() {
        let noTrueHeading = HeadingReading(rawTrueHeading: -1, rawAccuracy: 5)
        let noAccuracy = HeadingReading(rawTrueHeading: 72, rawAccuracy: -1)

        #expect(noTrueHeading.trueHeading == nil)
        #expect(noTrueHeading.accuracy == 5)
        #expect(noAccuracy.trueHeading == 72)
        #expect(noAccuracy.accuracy == nil)
    }

    @Test("Raw zero is a real heading (north) and a real accuracy, not invalid")
    func rawZeroIsNorth() {
        let north = HeadingReading(rawTrueHeading: 0, rawAccuracy: 0)

        #expect(north.trueHeading == 0)
        #expect(north.accuracy == 0)
    }

    @Test("Heading is kept within 0..<360")
    func headingWraps() {
        #expect(HeadingReading(trueHeading: 360, accuracy: 5).trueHeading == 0)
    }

    // MARK: - Fake: session contract

    @Test("Start runs a session and delivers readings")
    func fakeStartDelivers() async {
        let fake = FakeHeadingService()
        var readings = fake.start().makeAsyncIterator()

        fake.send(HeadingReading(trueHeading: 140, accuracy: 3))

        #expect(fake.isRunning)
        #expect(fake.startCount == 1)
        #expect(await readings.next() == HeadingReading(trueHeading: 140, accuracy: 3))
    }

    @Test("Stop ends the session and finishes the stream")
    func fakeStopFinishes() async {
        let fake = FakeHeadingService()
        var readings = fake.start().makeAsyncIterator()

        fake.stop()

        #expect(!fake.isRunning)
        #expect(fake.stopCount == 1)
        #expect(await readings.next() == nil)
    }

    @Test("Stop when not running does nothing")
    func fakeStopWhenStopped() {
        let fake = FakeHeadingService()

        fake.stop()

        #expect(fake.stopCount == 0)
    }

    @Test("Starting again ends the previous session's stream")
    func fakeRestartEndsPrevious() async {
        let fake = FakeHeadingService()
        var first = fake.start().makeAsyncIterator()
        var second = fake.start().makeAsyncIterator()

        fake.send(HeadingReading(trueHeading: 288, accuracy: 4))

        #expect(await first.next() == nil)
        #expect(await second.next() == HeadingReading(trueHeading: 288, accuracy: 4))
        #expect(fake.startCount == 2)
        #expect(fake.stopCount == 1)
        #expect(fake.isRunning)
    }

    /// The safety net: a consumer whose task is cancelled (the view went
    /// away) mustn't leave the sensors running.
    @Test("Cancelling the consumer stops the session")
    func fakeCancelledConsumerStops() async {
        let fake = FakeHeadingService()
        let stream = fake.start()
        let consumer = Task { for await _ in stream {} }

        consumer.cancel()
        await consumer.value
        await waitUntilStopped(fake)

        #expect(!fake.isRunning)
        #expect(fake.stopCount == 1)
    }

    @Test("Dropping the stream unread stops the session")
    func fakeDroppedStreamStops() async {
        let fake = FakeHeadingService()
        _ = fake.start()

        await waitUntilStopped(fake)

        #expect(!fake.isRunning)
        #expect(fake.stopCount == 1)
    }

    /// A late `onTermination` from an old session mustn't stop the new one.
    @Test("An old session ending late doesn't stop a newer one")
    func fakeLateTerminationIgnored() async {
        let fake = FakeHeadingService()
        _ = fake.start()
        // Kept alive: dropping a stream ends its session, which is a
        // different path (the abandoned-consumer safety net).
        let current = fake.start()

        // Let the first stream's termination hop land.
        for _ in 0..<Self.maxYieldsForTermination { await Task.yield() }

        withExtendedLifetime(current) {
            #expect(fake.isRunning)
            #expect(fake.stopCount == 1)
        }
    }

    @Test("Readings sent while stopped are dropped")
    func fakeSendWhenStopped() async {
        let fake = FakeHeadingService()
        var readings = fake.start().makeAsyncIterator()
        fake.stop()

        fake.send(HeadingReading(trueHeading: 72, accuracy: 5))

        #expect(await readings.next() == nil)
    }

    // MARK: - CoreLocationHeadingService without a compass

    /// The simulator path, and any device without a magnetometer: no sensors
    /// start, and the compass hears a single "unavailable".
    @Test(
        "With no compass, start yields unavailable and stop finishes",
        .enabled(if: !CLLocationManager.headingAvailable(), "needs a device without a compass (the simulator)")
    )
    func realServiceWithoutCompass() async {
        let service = CoreLocationHeadingService()
        var readings = service.start().makeAsyncIterator()

        #expect(service.isRunning)
        #expect(await readings.next() == .unavailable)

        service.stop()

        #expect(!service.isRunning)
        #expect(await readings.next() == nil)
    }

    @Test("Real service: stop before start does nothing")
    func realServiceStopBeforeStart() {
        let service = CoreLocationHeadingService()

        service.stop()

        #expect(!service.isRunning)
    }

    @Test("Real service: cancelling the consumer stops the session")
    func realServiceCancelledConsumerStops() async {
        let service = CoreLocationHeadingService()
        let stream = service.start()
        let consumer = Task { for await _ in stream {} }

        consumer.cancel()
        await consumer.value
        for _ in 0..<Self.maxYieldsForTermination where service.isRunning {
            await Task.yield()
        }

        #expect(!service.isRunning)
    }

    // MARK: - Helpers

    private func waitUntilStopped(_ fake: FakeHeadingService) async {
        for _ in 0..<Self.maxYieldsForTermination where fake.isRunning {
            await Task.yield()
        }
    }
}
