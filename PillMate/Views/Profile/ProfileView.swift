import Foundation
import SwiftUI
struct ProfileView: View {
    @State private var isSignedIn = false
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var authMode: EmailAuthMode?
    @State private var medicineReminders = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                profileHeader

                if isSignedIn {
                    signedInProfile
                } else {
                    signedOutProfile
                }

                appInformationSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppColors.background)
        .sheet(item: $authMode) { mode in
            EmailAuthView(mode: mode) { name, email in
                userName = name.isEmpty ? "PillMate User" : name
                userEmail = email
                isSignedIn = true
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var profileHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Profile")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Your personal details and preferences")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .foregroundStyle(AppColors.accent)
        }
    }

    private var signedOutProfile: some View {
        VStack(spacing: 18) {
            VStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accentSurface, Color(red: 0.77, green: 0.70, blue: 0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "envelope.badge.person.crop")
                        .font(.system(size: 34))
                        .foregroundStyle(AppColors.accentDeep)
                }
                .frame(width: 78, height: 78)

                Text("Keep your health story together")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("Create an account to protect your medicine records and prepare for cloud sync across devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    authMode = .signUp
                } label: {
                    Text("Create account with email")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    authMode = .signIn
                } label: {
                    Text("Already have an account? Sign in")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColors.accentDeep)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .shadow(color: AppColors.cardShadow, radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 14) {
                Text("What your profile keeps")
                    .font(.headline)
                profileBenefit(icon: "person.text.rectangle", title: "Personal health profile", subtitle: "Name, date of birth, allergies and conditions")
                profileBenefit(icon: "bell.badge", title: "Reminder preferences", subtitle: "Medicine notifications")
                profileBenefit(icon: "stethoscope", title: "Care contacts", subtitle: "Doctor and emergency contact information")
                profileBenefit(icon: "lock.shield", title: "Privacy and data", subtitle: "Export, account security and data controls")
            }
            .padding(17)
            .background(AppColors.accentSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var signedInProfile: some View {
        VStack(spacing: 14) {
            accountCard
            profileSection(title: "Health profile") {
                profileRow(icon: "person", title: "Name", value: userName)
                profileDivider
                profileRow(icon: "ruler", title: "Height", value: "165 cm")
                profileDivider
                profileRow(icon: "scalemass", title: "Weight", value: "55 kg")
                profileDivider
                profileRow(icon: "birthday.cake", title: "Date of birth", value: "Add")
                profileDivider
                profileRow(icon: "allergens", title: "Allergies", value: "None added")
                profileDivider
                profileRow(icon: "heart.text.square", title: "Health conditions", value: "Add")
            }

            profileSection(title: "Reminders") {
                profileToggle(icon: "pills", title: "Medicine reminders", isOn: $medicineReminders)
            }

            profileSection(title: "Care and safety") {
                profileRow(icon: "stethoscope", title: "Primary doctor", value: "Dr. Chen")
                profileDivider
                profileRow(icon: "phone.badge.waveform", title: "Emergency contact", value: "Add")
            }

            profileSection(title: "Privacy and data") {
                profileRow(icon: "square.and.arrow.up", title: "Export health summary", value: "PDF")
                profileDivider
                profileRow(icon: "lock.shield", title: "Account & security", value: "Manage")
            }

            Button(role: .destructive) {
                isSignedIn = false
            } label: {
                Text("Sign out")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var accountCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentSurface, Color(red: 0.77, green: 0.70, blue: 0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(String(userName.prefix(1)).uppercased())
                    .font(.title3.bold())
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.headline)
                Text(userEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Email account", systemImage: "checkmark.seal.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(AppColors.accentDeep)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppColors.accentSurface, Color(red: 0.79, green: 0.73, blue: 0.98)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    private var appInformationSection: some View {
        profileSection(title: "PillMate") {
            profileRow(icon: "star.fill", title: "Rate the app", value: "")
            profileDivider
            profileRow(icon: "bubble.left.and.bubble.right", title: "Feedback", value: "")
            profileDivider
            profileRow(icon: "doc.text", title: "Terms of Use", value: "")
            profileDivider
            profileRow(icon: "hand.raised", title: "Privacy Policy", value: "")
        }
    }

    private func profileBenefit(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.accent)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func profileSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 10, y: 4)
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
    }

    private func profileToggle(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)
            Toggle(title, isOn: isOn)
                .font(.subheadline)
                .tint(AppColors.accent)
        }
    }

    private var profileDivider: some View {
        Divider().opacity(0.55)
    }
}
