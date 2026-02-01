//
//  PassportTab.swift
//  TwinAct Field Companion
//
//  Tab definitions for the enhanced Passport view AASX explorer.
//

import SwiftUI

// MARK: - Passport Tab

/// Tabs available in the Passport view for exploring AASX content.
public enum PassportTab: String, CaseIterable, Identifiable {
    case overview
    case content
    case structure

    public var id: String { rawValue }

    /// Display title for the tab.
    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .content: return "Content"
        case .structure: return "Structure"
        }
    }

    /// SF Symbol icon for the tab.
    public var icon: String {
        switch self {
        case .overview: return "doc.text.fill"
        case .content: return "photo.on.rectangle.angled"
        case .structure: return "folder.fill"
        }
    }

    /// Accessibility label for the tab.
    public var accessibilityLabel: String {
        switch self {
        case .overview: return "Overview tab showing Digital Product Passport information"
        case .content: return "Content tab showing images, documents, and 3D models"
        case .structure: return "Structure tab showing AASX package contents and JSON structure"
        }
    }
}
