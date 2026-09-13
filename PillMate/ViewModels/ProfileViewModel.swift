import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var userName = ""
    @Published var userEmail = ""
    @Published var isSignedIn = false
}
