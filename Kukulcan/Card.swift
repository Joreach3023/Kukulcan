import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Ne redéclare PAS UTType.elementClashCard ici : on l'a déjà dans Types.swift

extension Card: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        // Réutilise l'UTType défini dans Types.swift
        CodableRepresentation(contentType: .elementClashCard)
    }
}

