//
//  ActivityView.swift
//  Divvy
//

import SwiftUI

struct ActivityView: View {
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        ZStack {
            Color.divvyBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Activity")
                        .font(DivvyTypography.title1)
                        .foregroundStyle(Color.divvyText)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.divvyPrimary)
                    Spacer()
                } else if viewModel.events.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No activity yet",
                        message: "Expenses and settlements across your groups will appear here"
                    )
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(groupedEventKeys, id: \.self) { dateKey in
                                Section {
                                    ForEach(groupedEvents[dateKey] ?? []) { event in
                                        ActivityEventRow(event: event)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 4)
                                    }
                                } header: {
                                    HStack {
                                        Text(dateKey)
                                            .font(DivvyTypography.captionMedium)
                                            .foregroundStyle(Color.divvySubtext)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 8)
                                        Spacer()
                                    }
                                    .background(Color.divvyBackground)
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Grouping by date

    private var groupedEvents: [String: [ActivityEvent]] {
        Dictionary(grouping: viewModel.events) { sectionTitle(for: $0.date) }
    }

    private var groupedEventKeys: [String] {
        // Preserve chronological order of sections
        var seen = Set<String>()
        return viewModel.events.compactMap { event in
            let key = sectionTitle(for: event.date)
            if seen.contains(key) { return nil }
            seen.insert(key)
            return key
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let components = cal.dateComponents([.day], from: date, to: Date())
        if let days = components.day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.wide).day().year())
    }
}

// MARK: - Activity Event Row

struct ActivityEventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 14) {
            // Left icon: category icon or settlement icon
            ZStack {
                RoundedRectangle(cornerRadius: DivvyRadius.tag)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            // Middle: title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(DivvyTypography.bodyMedium)
                    .foregroundStyle(Color.divvyText)
                    .lineLimit(1)
                Text(event.subtitle)
                    .font(DivvyTypography.caption)
                    .foregroundStyle(Color.divvySubtext)
                    .lineLimit(1)
            }

            Spacer()

            // Right: amount + time
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(event.currency) \(event.amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(DivvyTypography.bodyMedium)
                    .foregroundStyle(amountColor)
                Text(event.date.formatted(.dateTime.hour().minute()))
                    .font(DivvyTypography.caption)
                    .foregroundStyle(Color.divvySubtext)
            }
        }
        .padding(14)
        .glassCard()
    }

    private var iconName: String {
        switch event.type {
        case .expenseAdded, .expenseUpdated:
            return event.category?.icon ?? "tag.fill"
        case .settlementMade:
            return "checkmark.seal.fill"
        }
    }

    private var iconColor: Color {
        switch event.type {
        case .expenseAdded, .expenseUpdated:
            if let cat = event.category {
                return Color(hex: cat.color)
            }
            return Color.divvyPrimary
        case .settlementMade:
            return Color.divvySuccess
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.15)
    }

    private var amountColor: Color {
        switch event.type {
        case .settlementMade:
            return Color.divvySuccess
        default:
            return Color.divvyText
        }
    }
}
