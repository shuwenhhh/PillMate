import Foundation
import Combine

@MainActor
final class RecordsViewModel: ObservableObject {
    @Published var selectedDay: Int = 22
    @Published var selectedMonth: Int = 8
}
