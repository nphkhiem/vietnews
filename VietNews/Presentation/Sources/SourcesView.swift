import SwiftUI

/// Every source the app reads, what state it is in, and a switch for each.
///
/// A source that broke used to be a silent hole in the feed: the reader saw fewer articles and
/// had nothing to look at to find out why. Failing sources are lifted to the top for the same
/// reason, because being told what is wrong is why anyone opens this screen.
struct SourcesView: View {
    /// Owned rather than observed. A `NavigationLink` re-evaluates its destination as the parent
    /// redraws, so a view model built there would be discarded and rebuilt underneath the reader
    /// mid-interaction.
    @StateObject private var viewModel: SourcesViewModel
    let language: Language
    let makeSubscriptionViewModel: () -> FeedSubscriptionViewModel

    @State private var isAddingFeed = false

    init(
        language: Language,
        makeSubscriptionViewModel: @escaping () -> FeedSubscriptionViewModel,
        makeViewModel: @escaping () -> SourcesViewModel
    ) {
        self.language = language
        self.makeSubscriptionViewModel = makeSubscriptionViewModel
        _viewModel = StateObject(wrappedValue: makeViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !viewModel.failing.isEmpty {
                    SettingsGroup(title: L10n.sourcesSectionAttention(language)) {
                        rows(viewModel.failing)
                    }
                }

                SettingsGroup(title: L10n.sourcesSectionBuiltIn(language)) {
                    rows(viewModel.builtIn)
                }

                SettingsGroup(title: L10n.sourcesSectionYours(language)) {
                    VStack(spacing: 0) {
                        if !viewModel.userFeeds.isEmpty {
                            rows(viewModel.userFeeds)
                            Divider().overlay(Tokens.Palette.hairline)
                        }

                        // The row the approved mockup showed, held back until ticket 31 built
                        // the sheet behind it. It goes somewhere now.
                        Button { isAddingFeed = true } label: {
                            SettingsLabelledRow(
                                title: L10n.sourcesAdd(language),
                                detail: L10n.sourcesAddDetail(language),
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("sources.addFeed")
                    }
                }
            }
            .padding(.bottom, Tokens.Space.xxxl)
        }
        .background(Tokens.Palette.background)
        .navigationTitle(L10n.sourcesTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingFeed) {
            FeedSubscriptionSheet(
                viewModel: makeSubscriptionViewModel(),
                language: language,
                onFinished: {
                    isAddingFeed = false
                    // The new feed belongs in the list behind the sheet straight away.
                    viewModel.reload()
                }
            )
        }
    }

    private func rows(_ listings: [SourceListing]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(listings.enumerated()), id: \.element.id) { index, listing in
                SourceRow(
                    listing: listing,
                    language: language,
                    onToggle: { viewModel.setEnabled($0, for: listing.identity) }
                )
                if index < listings.count - 1 {
                    Divider().overlay(Tokens.Palette.hairline)
                }
            }
        }
    }
}

private struct SourceRow: View {
    let listing: SourceListing
    let language: Language
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.name)
                    .font(Tokens.Typography.category.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(detail)
                    .font(Tokens.Typography.summary)
                    // The failure is stated in words as well as coloured, so it survives being
                    // read aloud or seen without colour.
                    .foregroundStyle(listing.isFailing ? Tokens.Palette.accent : Tokens.Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(get: { listing.isEnabled }, set: onToggle))
                .labelsHidden()
                // Ink, not the accent. Every source is on by default, so an accent tint would
                // put seven vermilion blocks on one screen and leave the accent signalling
                // nothing. It stays reserved for the failures above.
                .tint(Tokens.Palette.ink)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.name). \(detail)")
        .accessibilityIdentifier("sources.row.\(listing.id)")
    }

    /// One line saying either what is wrong or what the source covers, never both, because a
    /// working source has nothing to report and a broken one has nothing else worth saying.
    private var detail: String {
        guard let cause = listing.health.lastFailure else {
            guard let last = listing.health.lastSucceededAt else { return listing.scope }
            return "\(listing.scope). \(L10n.sourcesUpdated(language, Self.relative(last, language)))"
        }
        return "\(cause.message(in: language)) \(lastSuccess)"
    }

    private var lastSuccess: String {
        guard let last = listing.health.lastSucceededAt else {
            return L10n.sourcesLastWorkedNever(language)
        }
        return L10n.sourcesLastWorked(language, Self.relative(last, language))
    }

    private static func relative(_ date: Date, _ language: Language) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = language.locale
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension SourceFailureCause {
    /// The same wording the feed's banners use, so a reader meets one vocabulary rather than
    /// two descriptions of the same outage.
    func message(in language: Language) -> String {
        switch self {
        case .timedOut: return L10n.errorTimedOut(language)
        case .rejected: return L10n.errorRejected(language)
        case .rateLimited: return L10n.errorRateLimited(language)
        case .unparseable: return L10n.errorUnparseable(language)
        case .unreachable: return L10n.errorUnreachable(language)
        case .mixed: return L10n.errorGeneric(language)
        }
    }
}
