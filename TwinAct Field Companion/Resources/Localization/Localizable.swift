//
//  Localizable.swift
//  TwinAct Field Companion
//
//  Lightweight localization helpers.
//

import Foundation

enum L10n {
    /// Look up a localized string by key.
    static func tr(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }
}
