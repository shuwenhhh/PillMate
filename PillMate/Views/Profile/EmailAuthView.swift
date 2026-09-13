import Foundation
import SwiftUI
struct EmailAuthView: View {
    let mode: EmailAuthMode
    let onComplete: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var acceptedTerms = false

    private var isSignUp: Bool { mode == .signUp }

    private var formIsValid: Bool {
        let basicFieldsAreValid = email.contains("@") && password.count >= 8
        if isSignUp {
            return basicFieldsAreValid && !name.trimmingCharacters(in: .whitespaces).isEmpty && password == confirmPassword && acceptedTerms
        }
        return basicFieldsAreValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isSignUp ? "Welcome to PillMate" : "Welcome back")
                            .font(.title3.bold())
                        Text(isSignUp ? "Create an account with your email." : "Sign in to your PillMate account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Account details") {
                    if isSignUp {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                    }
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password (at least 8 characters)", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                    if isSignUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                }

                if isSignUp {
                    Section {
                        Toggle("I agree to the Privacy Policy and Terms of Use", isOn: $acceptedTerms)
                            .font(.caption)
                            .tint(AppColors.accent)
                    }
                }

                Section {
                    Button {
                        onComplete(name, email)
                        dismiss()
                    } label: {
                        Text(isSignUp ? "Create account" : "Sign in")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(formIsValid ? AppColors.accent : AppColors.accentMuted.opacity(0.45))
                    .disabled(!formIsValid)
                }

                Section {
                    Label("Your health data should only be synced after secure authentication is connected.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .tint(AppColors.accent)
            .navigationTitle(isSignUp ? "Create account" : "Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
