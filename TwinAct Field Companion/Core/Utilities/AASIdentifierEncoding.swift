//
//  AASIdentifierEncoding.swift
//  TwinAct Field Companion
//
//  AAS API v3 compliant Base64url encoding for identifiers.
//  This is critical for all AAS API interoperability - all API v3 calls
//  use these encoded identifiers in URL paths.
//

import Foundation

// MARK: - AAS Identifier Encoding

/// Encodes an AAS identifier (URN, IRI, etc.) to Base64url format WITHOUT padding
/// per AAS API v3 specification for use in URL paths.
///
/// Base64url differs from standard Base64:
/// - Uses `-` instead of `+`
/// - Uses `_` instead of `/`
/// - NO trailing `=` padding
///
/// Example:
///   Input:  "https://example.com/aas/1234567890"
///   Output: "aHR0cHM6Ly9leGFtcGxlLmNvbS9hYXMvMTIzNDU2Nzg5MA"
///
/// - Parameter identifier: The AAS identifier string to encode (URN, IRI, etc.)
/// - Returns: Base64url encoded string without padding
@inline(__always)
public func aasB64Url(_ identifier: String) -> String {
    // Handle empty string case
    guard !identifier.isEmpty else {
        return ""
    }

    // Convert to UTF-8 data
    guard let data = identifier.data(using: .utf8) else {
        return ""
    }

    // Encode to standard Base64
    var base64 = data.base64EncodedString()

    // Convert to Base64url:
    // 1. Replace '+' with '-'
    // 2. Replace '/' with '_'
    // 3. Remove trailing '=' padding
    base64 = base64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")

    // Remove padding
    while base64.hasSuffix("=") {
        base64.removeLast()
    }

    return base64
}

/// Decodes a Base64url-encoded AAS identifier back to the original string.
/// Handles the re-addition of padding for standard Base64 decoding.
///
/// - Parameter encoded: The Base64url encoded string (without padding)
/// - Returns: The decoded original identifier string, or nil if decoding fails
@inline(__always)
public func aasB64UrlDecode(_ encoded: String) -> String? {
    // Handle empty string case
    guard !encoded.isEmpty else {
        return ""
    }

    // Convert from Base64url to standard Base64:
    // 1. Replace '-' with '+'
    // 2. Replace '_' with '/'
    var base64 = encoded
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")

    // Re-add padding to make length a multiple of 4
    let paddingNeeded = (4 - (base64.count % 4)) % 4
    base64 += String(repeating: "=", count: paddingNeeded)

    // Decode from Base64
    guard let data = Data(base64Encoded: base64) else {
        return nil
    }

    // Convert to UTF-8 string
    return String(data: data, encoding: .utf8)
}

// MARK: - String Extension for Convenience

public extension String {
    /// Encodes this string as an AAS identifier using Base64url encoding.
    /// Convenience wrapper around `aasB64Url(_:)`.
    var aasEncoded: String {
        aasB64Url(self)
    }

    /// Decodes this Base64url-encoded string back to the original AAS identifier.
    /// Convenience wrapper around `aasB64UrlDecode(_:)`.
    var aasDecoded: String? {
        aasB64UrlDecode(self)
    }
}

// MARK: - AAS Encoding Namespace (Alternative API)

/// Namespace for AAS identifier encoding utilities.
/// Provides a cleaner API for encoding/decoding operations.
public enum AASEncoding {
    /// Encodes an identifier to Base64url format for AAS API v3.
    @inline(__always)
    public static func encode(_ identifier: String) -> String {
        aasB64Url(identifier)
    }

    /// Decodes a Base64url-encoded identifier back to original.
    @inline(__always)
    public static func decode(_ encoded: String) -> String? {
        aasB64UrlDecode(encoded)
    }
}
