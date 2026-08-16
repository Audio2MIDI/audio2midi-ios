import Audio2MIDICore
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Phase { case launching, signedOut, signedIn }

    let service: any Audio2MIDIService
    var phase: Phase = .launching
    var account: Account?
    var library: [LibraryItem] = []
    var isLoading = false
    var errorMessage: String?
    var selectedTab = 0

    init(service: any Audio2MIDIService) { self.service = service }

    static func make() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        if let fixture = arguments.first(where: { $0.hasPrefix("-fixture=") })?.split(separator: "=").last,
           let scenario = FixtureService.Scenario(rawValue: String(fixture)) {
            return AppModel(service: FixtureService(scenario: scenario))
        }
        return AppModel(service: APIClient())
    }

    func bootstrap() async {
        do {
            account = try await service.currentAccount()
            phase = .signedIn
            await refreshLibrary()
        } catch APIError.unauthenticated {
            phase = .signedOut
        } catch {
            phase = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func verify(email: String, code: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            account = try await service.verifyEmail(email: email, code: code)
            phase = .signedIn
            await refreshLibrary()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshLibrary() async {
        isLoading = true
        defer { isLoading = false }
        do { library = try await service.library() }
        catch { errorMessage = error.localizedDescription }
    }

    func registerPush(token: String) async {
        guard phase == .signedIn else { return }
        let key = "push.installation-id"
        let defaults = UserDefaults.standard
        let installationID: UUID
        if let stored = defaults.string(forKey: key), let parsed = UUID(uuidString: stored) {
            installationID = parsed
        } else {
            installationID = UUID()
            defaults.set(installationID.uuidString, forKey: key)
        }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            try await service.registerPush(
                installationID: installationID,
                token: token,
                environment: environment,
                locale: Locale.current.language.languageCode?.identifier == "ru" ? "ru" : "en"
            )
        } catch { errorMessage = error.localizedDescription }
    }
}
