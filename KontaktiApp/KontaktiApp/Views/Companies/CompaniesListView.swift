import SwiftUI

struct CompaniesListView: View {
    @StateObject private var vm = CompaniesViewModel()
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Offline banner
                if !network.isConnected {
                    OfflineBanner()
                }

                if vm.isLoading && vm.companies.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if vm.companies.isEmpty && !vm.isLoading {
                    EmptyStateView(
                        icon: "building.2",
                        title: "No companies",
                        subtitle: nil
                    )
                } else {
                    List {
                        ForEach(vm.companies) { company in
                            NavigationLink(value: company) {
                                CompanyRowView(company: company)
                            }
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationDestination(for: Company.self) { company in
                        CompanyDetailView(company: company)
                    }
                    .refreshable {
                        await vm.load(reset: true)
                    }
                }
            }
        }
        .navigationTitle("Companies")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $vm.searchText, prompt: "Search companies")
        .onChange(of: vm.searchText) {
            vm.onSearchChange()
        }
        .task {
            await vm.load()
        }
    }
}

private struct CompanyRowView: View {
    let company: Company

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: "building.2")
                    .font(.body)
                    .foregroundColor(Color(.systemGray))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(company.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let domain = company.domain {
                    Text(domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    if let industry = company.industry {
                        Text(industry)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }

                    if let count = company.peopleCount, count > 0 {
                        Text("\(count) \(count == 1 ? "person" : "people")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
