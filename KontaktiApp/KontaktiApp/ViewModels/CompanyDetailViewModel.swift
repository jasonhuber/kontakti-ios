import Foundation
import SwiftUI

@MainActor
final class CompanyDetailViewModel: ObservableObject {
    @Published var company: Company?
    @Published var people: [Person] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        do {
            async let companyTask = api.getCompany(id)
            async let peopleTask = api.getCompanyPeople(id)
            company = try await companyTask
            people = (try? await peopleTask) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
