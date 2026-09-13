import Foundation

struct UserProfileData: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var heightCentimeters: Double?
    var weightKilograms: Double?

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String = "",
        heightCentimeters: Double? = nil,
        weightKilograms: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
    }
}
