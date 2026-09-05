import Foundation
import Testing
@testable import MacTermXCore

@Suite("XonXoffFlowController")
struct XonXoffFlowControllerTests {
    @Test("passes data through untouched when no XON/XOFF bytes appear")
    func passthroughWhenNoControlBytes() async {
        let controller = XonXoffFlowController()
        let filtered = await controller.filterIncoming(Data("hello".utf8))
        #expect(filtered == Data("hello".utf8))
        #expect(await controller.isHalted == false)
    }

    @Test("strips XOFF and halts, strips XON and resumes")
    func stripsControlBytesAndTracksHaltState() async {
        let controller = XonXoffFlowController()

        let afterXoff = await controller.filterIncoming(Data([0x41, 0x13, 0x42]))
        #expect(afterXoff == Data([0x41, 0x42]))
        #expect(await controller.isHalted == true)

        let afterXon = await controller.filterIncoming(Data([0x43, 0x11, 0x44]))
        #expect(afterXon == Data([0x43, 0x44]))
        #expect(await controller.isHalted == false)
    }

    @Test("waitUntilClearToSend blocks while halted and resumes on XON")
    func waitBlocksUntilResumed() async throws {
        let controller = XonXoffFlowController()
        _ = await controller.filterIncoming(Data([0x13])) // XOFF
        #expect(await controller.isHalted == true)

        let waiter = Task {
            await controller.waitUntilClearToSend()
        }
        // Give the waiter a moment to actually start waiting.
        try await Task.sleep(for: .milliseconds(50))
        #expect(waiter.isCancelled == false)

        _ = await controller.filterIncoming(Data([0x11])) // XON
        await waiter.value // must complete promptly; test times out otherwise
    }

    @Test("waitUntilClearToSend returns immediately when not halted")
    func waitReturnsImmediatelyWhenClear() async {
        let controller = XonXoffFlowController()
        await controller.waitUntilClearToSend()
        #expect(await controller.isHalted == false)
    }
}
