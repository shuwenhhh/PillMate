import Foundation
import SwiftUI
enum EmailAuthMode: String, Identifiable {
    case signUp
    case signIn

    var id: String { rawValue }
}

