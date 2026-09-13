import Foundation
import Combine

@MainActor
final class MedicinesViewModel: ObservableObject {
    @Published var selectedSection: Int = 0
}
