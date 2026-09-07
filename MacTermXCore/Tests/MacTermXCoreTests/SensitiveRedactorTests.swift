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
