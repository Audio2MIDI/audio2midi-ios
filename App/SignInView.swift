import Audio2MIDICore
import SwiftUI

struct SignInView: View {
    @Bindable var model: AppModel
    @State private var email = ""
    @State private var code = ""
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Wordmark().padding(.top, 24)
            Spacer()
            Text(step == 0 ? "Your music workspace" : "Check your email")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(step == 0 ? "Sign in to keep projects synced across the web, Telegram, and iPhone." : "Enter the confirmation code sent to \(email).")
                .foregroundStyle(StudioColor.secondary)
                .lineSpacing(3)
            if step == 0 {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    .padding(16).background(StudioColor.raised).clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("signin.email")
                Button("Continue") {
                    Task {
                        do { try await model.service.startEmailLogin(email: email); step = 1 }
                        catch { model.errorMessage = error.localizedDescription }
                    }
                }
                .disabled(!email.contains("@"))
                .buttonStyle(StudioButtonStyle(prominent: true))
                .accessibilityIdentifier("signin.continue")
            } else {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .padding(16).background(StudioColor.raised).clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("signin.code")
                Button("Sign in") { Task { _ = await model.verify(email: email, code: code) } }
                    .disabled(code.count < 6 || model.isLoading)
                    .buttonStyle(StudioButtonStyle(prominent: true))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(StudioColor.black.ignoresSafeArea())
    }
}

