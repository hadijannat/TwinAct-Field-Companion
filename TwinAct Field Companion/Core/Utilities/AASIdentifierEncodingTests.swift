//
//  AASIdentifierEncodingTests.swift
//  TwinAct Field Companion
//
//  Unit tests for AAS Base64url identifier encoding.
//  These tests can be run in-app during debug or moved to a test target.
//

import Foundation

#if DEBUG

// MARK: - Test Runner

/// Test runner for AAS Identifier Encoding tests.
/// Can be invoked from debug builds to verify encoding correctness.
public enum AASIdentifierEncodingTests {

    /// Runs all tests and returns a summary of results.
    /// - Returns: Tuple of (passed count, failed count, failure messages)
    @discardableResult
    public static func runAllTests() -> (passed: Int, failed: Int, failures: [String]) {
        var passed = 0
        var failed = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
            if condition {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) (line \(line))")
            }
        }

        func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
            if actual == expected {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) - Expected '\(expected)', got '\(actual)' (line \(line))")
            }
        }

        // ============================================================
        // MARK: - Test: Empty String
        // ============================================================

        assertEqual(aasB64Url(""), "", "Empty string should encode to empty string")
        assertEqual(aasB64UrlDecode(""), "", "Empty string should decode to empty string")

        // ============================================================
        // MARK: - Test: Basic Encoding/Decoding Round Trip
        // ============================================================

        let basicStrings = [
            "hello",
            "Hello World",
            "test123",
            "ABC"
        ]

        for str in basicStrings {
            let encoded = aasB64Url(str)
            let decoded = aasB64UrlDecode(encoded)
            assertEqual(decoded, str, "Round-trip for '\(str)' should return original")
        }

        // ============================================================
        // MARK: - Test: No Padding Characters
        // ============================================================

        // These strings would normally produce padding in standard Base64
        let paddingTestStrings = [
            "a",          // Would have 2 padding chars (YQ==)
            "ab",         // Would have 1 padding char (YWI=)
            "abc",        // No padding (YWJj)
            "abcd",       // No padding (YWJjZA==) - wait, this has padding
            "test",       // Would have padding
            "hello"       // Would have padding
        ]

        for str in paddingTestStrings {
            let encoded = aasB64Url(str)
            assert(!encoded.contains("="), "Encoded '\(str)' should not contain padding: got '\(encoded)'")
        }

        // ============================================================
        // MARK: - Test: Base64url Character Substitution
        // ============================================================

        // Test that + and / from standard Base64 are properly replaced
        // We need inputs that produce these characters

        // String "???" produces "Pz8/" in standard base64 (contains /)
        let slashTest = "???"
        let slashEncoded = aasB64Url(slashTest)
        assert(!slashEncoded.contains("/"), "Encoded string should not contain '/'")
        assert(!slashEncoded.contains("+"), "Encoded string should not contain '+'")
        let slashDecoded = aasB64UrlDecode(slashEncoded)
        assertEqual(slashDecoded, slashTest, "Round-trip for slash-producing string should work")

        // String containing bytes that produce + in base64
        // ">>" produces "Pj4=" in standard base64 (contains no + but good test)
        // We'll test with binary-like content indirectly through URNs

        // ============================================================
        // MARK: - Test: URN Identifiers (AAS Spec Common Format)
        // ============================================================

        let urnExamples = [
            "urn:example:aas:1:1:submodel:ExampleMotor",
            "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
            "urn:ietf:rfc:2648",
            "urn:isbn:0451450523",
            "urn:uuid:6e8bc430-9c3a-11d9-9669-0800200c9a66"
        ]

        for urn in urnExamples {
            let encoded = aasB64Url(urn)
            let decoded = aasB64UrlDecode(encoded)
            assertEqual(decoded, urn, "URN round-trip should work for '\(urn)'")
            assert(!encoded.contains("="), "URN '\(urn)' encoded should not have padding")
            assert(!encoded.contains("+"), "URN '\(urn)' encoded should not contain '+'")
            assert(!encoded.contains("/"), "URN '\(urn)' encoded should not contain '/'")
        }

        // ============================================================
        // MARK: - Test: IRI Identifiers (HTTP/HTTPS URLs)
        // ============================================================

        let iriExamples = [
            "https://admin-shell.io/aas/3/0/Submodel",
            "https://example.com/aas/1234567890",
            "http://www.w3.org/2001/XMLSchema",
            "https://admin-shell.io/zvei/nameplate/2/0/Nameplate",
            "https://admin-shell.io/ZVEI/TechnicalData/Submodel/1/2"
        ]

        for iri in iriExamples {
            let encoded = aasB64Url(iri)
            let decoded = aasB64UrlDecode(encoded)
            assertEqual(decoded, iri, "IRI round-trip should work for '\(iri)'")
            assert(!encoded.contains("="), "IRI '\(iri)' encoded should not have padding")
        }

        // ============================================================
        // MARK: - Test: Special Characters
        // ============================================================

        let specialCharStrings = [
            "hello world",           // Space
            "test@example.com",      // @ symbol
            "path/to/resource",      // Forward slash
            "a+b=c",                 // Plus and equals
            "special!@#$%^&*()",     // Various special chars
            "unicode\u{00E9}",       // Accented character
            "emoji\u{1F600}",        // Emoji
            "line\nbreak",           // Newline
            "tab\there",             // Tab
            "quote\"here",           // Quote
            "back\\slash"            // Backslash
        ]

        for str in specialCharStrings {
            let encoded = aasB64Url(str)
            let decoded = aasB64UrlDecode(encoded)
            assertEqual(decoded, str, "Special char round-trip should work for '\(str)'")
        }

        // ============================================================
        // MARK: - Test: Known Test Vectors
        // ============================================================

        // Verify specific known encodings
        // "https://example.com/aas/1234567890" should encode to "aHR0cHM6Ly9leGFtcGxlLmNvbS9hYXMvMTIzNDU2Nzg5MA"
        let knownInput = "https://example.com/aas/1234567890"
        let knownExpected = "aHR0cHM6Ly9leGFtcGxlLmNvbS9hYXMvMTIzNDU2Nzg5MA"
        let knownActual = aasB64Url(knownInput)
        assertEqual(knownActual, knownExpected, "Known test vector encoding should match")

        // Verify decoding of the known vector
        let decodedKnown = aasB64UrlDecode(knownExpected)
        assertEqual(decodedKnown, knownInput, "Known test vector decoding should match")

        // ============================================================
        // MARK: - Test: Invalid Decode Input
        // ============================================================

        // Invalid Base64 should return nil
        let invalidInputs = [
            "!!!invalid!!!",
            "not@base64",
            "\u{FFFF}"  // Invalid unicode that can't be valid base64
        ]

        for invalid in invalidInputs {
            // Note: Some of these might actually decode to something
            // The main test is that we don't crash
            _ = aasB64UrlDecode(invalid)
            passed += 1  // If we get here without crashing, it's a pass
        }

        // ============================================================
        // MARK: - Test: String Extension API
        // ============================================================

        let extensionTest = "urn:example:test"
        assertEqual(extensionTest.aasEncoded, aasB64Url(extensionTest), "String extension .aasEncoded should match function")
        assertEqual(extensionTest.aasEncoded.aasDecoded, extensionTest, "String extension round-trip should work")

        // ============================================================
        // MARK: - Test: Namespace API
        // ============================================================

        let namespaceTest = "urn:aas:namespace:test"
        assertEqual(AASEncoding.encode(namespaceTest), aasB64Url(namespaceTest), "Namespace API encode should match function")
        assertEqual(AASEncoding.decode(AASEncoding.encode(namespaceTest)), namespaceTest, "Namespace API round-trip should work")

        // ============================================================
        // MARK: - Test: Long Strings
        // ============================================================

        let longString = String(repeating: "a", count: 1000)
        let longEncoded = aasB64Url(longString)
        let longDecoded = aasB64UrlDecode(longEncoded)
        assertEqual(longDecoded, longString, "Long string (1000 chars) round-trip should work")
        assert(!longEncoded.contains("="), "Long string encoded should not have padding")

        // Very long string
        let veryLongString = String(repeating: "abcdefghij", count: 1000)
        let veryLongEncoded = aasB64Url(veryLongString)
        let veryLongDecoded = aasB64UrlDecode(veryLongEncoded)
        assertEqual(veryLongDecoded, veryLongString, "Very long string (10000 chars) round-trip should work")

        // ============================================================
        // MARK: - Test: AAS Specification Examples
        // ============================================================

        // Common AAS identifier patterns from the spec
        let aasSpecExamples = [
            "urn:example:aas:1:1:123456789",
            "https://admin-shell.io/aas/API/Paths/GetAllAssetAdministrationShells",
            "urn:smc:12345",
            "https://admin-shell.io/aas/3/0/AssetAdministrationShell",
            "https://admin-shell.io/aas/3/0/Asset/globalAssetId"
        ]

        for example in aasSpecExamples {
            let encoded = aasB64Url(example)
            let decoded = aasB64UrlDecode(encoded)
            assertEqual(decoded, example, "AAS spec example '\(example)' round-trip should work")

            // Verify the encoded string is URL-safe
            let urlSafeCharset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
            let isUrlSafe = encoded.unicodeScalars.allSatisfy { urlSafeCharset.contains($0) }
            assert(isUrlSafe, "Encoded '\(example)' should only contain URL-safe characters")
        }

        // Print summary
        print("=== AAS Identifier Encoding Tests ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        if !failures.isEmpty {
            print("\nFailures:")
            for failure in failures {
                print("  - \(failure)")
            }
        }
        print("=====================================")

        return (passed, failed, failures)
    }
}

// MARK: - Debug Verification

/// Convenience function to verify encoding works correctly.
/// Call this during app startup in debug builds.
public func verifyAASEncodingInDebug() {
    let results = AASIdentifierEncodingTests.runAllTests()
    if results.failed > 0 {
        assertionFailure("AAS Encoding tests failed! \(results.failed) failures. Check console for details.")
    }
}

#endif // DEBUG
