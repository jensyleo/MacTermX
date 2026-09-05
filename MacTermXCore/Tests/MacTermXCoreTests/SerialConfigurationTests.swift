import Testing
@testable import MacTermXCore

@Suite("SerialConfiguration")
struct SerialConfigurationTests {
    @Test("defaults match common 8N1 115200 setup")
    func defaults() {
        let config = SerialConfiguration()
        #expect(config.baudRate == 115_200)
        #expect(config.dataBits == 8)
        #expect(config.stopBits == 1)
        #expect(config.parity == .none)
        #expect(config.flowControl == .none)
    }
}
