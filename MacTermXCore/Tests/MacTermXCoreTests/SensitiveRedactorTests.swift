import Foundation
import Testing
@testable import MacTermXCore

@Suite("SensitiveRedactor")
struct SensitiveRedactorTests {
    @Test("redacts a password assignment")
    func redactsPassword() {
        let result = SensitiveRedactor.redact("login: admin password=hunter2 done")
        #expect(!result.contains("hunter2"))
        #expect(result.contains("[REDACTED:password]"))
    }

    @Test("redacts an API key assignment")
    func redactsApiKey() {
        let result = SensitiveRedactor.redact("api_key: sk-abcdef123456")
        #expect(!result.contains("sk-abcdef123456"))
        #expect(result.contains("[REDACTED:api key]"))
    }

    @Test("redacts a bearer token")
    func redactsBearerToken() {
        let result = SensitiveRedactor.redact("Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc.def")
        #expect(!result.contains("eyJhbGciOiJIUzI1NiJ9"))
        #expect(result.contains("[REDACTED:bearer token]"))
    }

    @Test("redacts an AWS-style access key")
    func redactsAWSKey() {
        let result = SensitiveRedactor.redact("key=AKIAIOSFODNN7EXAMPLE")
        #expect(!result.contains("AKIAIOSFODNN7EXAMPLE"))
    }

    @Test("redacts a PEM private key block")
    func redactsPrivateKeyBlock() {
        let pem = "-----BEGIN RSA PRIVATE KEY-----\nMIIBOgIBAAJ...\n-----END RSA PRIVATE KEY-----"
        let result = SensitiveRedactor.redact("before \(pem) after")
        #expect(!result.contains("MIIBOgIBAAJ"))
        #expect(result.contains("[REDACTED:private key block]"))
    }

    @Test("leaves ordinary text untouched")
    func leavesOrdinaryTextAlone() {
        let text = "AT+STATUS\r\nOK\r\n"
        #expect(SensitiveRedactor.redact(text) == text)
    }
}

@Suite("StreamingRedactor")
struct StreamingRedactorTests {
    @Test("catches a secret split across two chunks that per-chunk redaction would miss")
    func catchesSecretSplitAcrossChunks() {
        let redactor = StreamingRedactor(overlapWindow: 16)
        let secret = "password=hunter2"
        let splitPoint = secret.index(secret.startIndex, offsetBy: 9) // right after "password="
        let firstHalf = String(secret[..<splitPoint])
        let secondHalf = String(secret[splitPoint...])

        // Naive per-chunk redaction would see "password=" and "hunter2"
        // separately and never match the pattern in either piece.
        #expect(SensitiveRedactor.redact(firstHalf) == firstHalf)

        var output = Data()
        output.append(redactor.process(Data(firstHalf.utf8)))
        output.append(redactor.process(Data(secondHalf.utf8)))
        output.append(redactor.flush())

        let result = String(decoding: output, as: UTF8.self)
        #expect(!result.contains("hunter2"))
        #expect(result.contains("[REDACTED:password]"))
    }

    @Test("eventually emits all fed data, redacted, once flushed")
    func flushReturnsRemainder() {
        let redactor = StreamingRedactor(overlapWindow: 8)
        var output = Data()
        output.append(redactor.process(Data("hello ".utf8)))
        output.append(redactor.process(Data("world".utf8)))
        output.append(redactor.flush())
        #expect(String(decoding: output, as: UTF8.self) == "hello world")
    }

    @Test("bounded memory: pending buffer never exceeds roughly 2x the overlap window")
    func staysBounded() {
        let redactor = StreamingRedactor(overlapWindow: 64)
        for _ in 0..<1000 {
            _ = redactor.process(Data(repeating: 0x41, count: 100))
        }
        // If this ever grew unbounded, flush() would be enormous; instead
        // it should be at most a couple of overlap windows' worth.
        #expect(redactor.flush().count <= 256)
    }
}
