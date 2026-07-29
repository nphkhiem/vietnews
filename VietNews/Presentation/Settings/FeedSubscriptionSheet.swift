import SwiftUI

/// Adding a feed, start to finish, with its confirm button always in view.
struct FeedSubscriptionSheet: View {
    @ObservedObject var viewModel: FeedSubscriptionViewModel
    let language: Language
    let onFinished: () -> Void

    @FocusState private var addressFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.l) {
                        addressField
                        categoryField
                        preview
                    }
                    .padding(.top, Tokens.Space.l)
                    .padding(.bottom, Tokens.Space.xxl)
                }

                // Below the scroll view rather than inside it, so the primary action is never
                // the thing the reader has to go looking for.
                primaryAction
            }
            .background(Tokens.Palette.background)
            .navigationTitle(L10n.subscribeTitle(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.subscribeCancel(language), action: onFinished)
                        .foregroundStyle(Tokens.Palette.accent)
                }
            }
        }
        .onAppear { addressFocused = true }
    }

    private var addressField: some View {
        SettingsField(title: L10n.subscribeAddress(language)) {
            TextField(L10n.subscribePlaceholder(language), text: $viewModel.address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($addressFocused)
                .font(Tokens.Typography.category)
                .padding(Tokens.Space.m)
                .background(Tokens.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))
                .accessibilityIdentifier("subscribe.address")

            // Said while the reader is still typing rather than held back until they submit.
            if case .invalid(let problem) = viewModel.addressState {
                problemLabel(problem)
            }
        }
    }

    private var categoryField: some View {
        SettingsField(title: L10n.settingsCategory(language)) {
            SegmentedControl(
                options: [NewsCategory.work, .technology],
                title: { $0.displayName(in: language) },
                selection: $viewModel.category
            )
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch viewModel.previewState {
        case .idle:
            EmptyView()
        case .checking:
            Text(L10n.subscribeChecking(language))
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .padding(.horizontal, Tokens.Space.l)
        case .failed(let problem):
            problemLabel(problem)
                .padding(.horizontal, Tokens.Space.l)
        case .found(let found):
            // The publication's own name and a few of its headlines. This is the proof the sheet
            // exists to give: the reader sees what they are about to follow before they follow it.
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text(found.title)
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(found.itemTitles, id: \.self) { title in
                    Text(title)
                        .font(Tokens.Typography.summary)
                        .foregroundStyle(Tokens.Palette.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Space.l)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("subscribe.preview")
        }
    }

    private var primaryAction: some View {
        Button(actionTitle) {
            if viewModel.canAdd {
                if viewModel.add() { onFinished() }
            } else {
                Task { await viewModel.check() }
            }
        }
        .font(Tokens.Typography.category.weight(.semibold))
        .foregroundStyle(isActionEnabled ? Tokens.Palette.onAccent : Tokens.Palette.inkTertiary)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.image)
                .fill(isActionEnabled ? Tokens.Palette.accent : Tokens.Palette.hairline)
        )
        .padding(.horizontal, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.l)
        .disabled(!isActionEnabled)
        .accessibilityIdentifier("subscribe.action")
    }

    /// One button that changes what it does: check first, then add. Two buttons would have made
    /// the reader choose between them when only one is ever the right move.
    private var actionTitle: String {
        viewModel.canAdd ? L10n.subscribeAdd(language) : L10n.subscribeCheck(language)
    }

    private var isActionEnabled: Bool {
        if viewModel.canAdd { return true }
        if case .usable = viewModel.addressState, viewModel.previewState != .checking { return true }
        return false
    }

    private func problemLabel(_ problem: FeedSubscriptionViewModel.Problem) -> some View {
        Text(problem.message(in: language))
            .font(Tokens.Typography.summary)
            .foregroundStyle(Tokens.Palette.accent)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("subscribe.problem")
    }
}

extension FeedSubscriptionViewModel.Problem {
    func message(in language: Language) -> String {
        switch self {
        case .notAnAddress: return L10n.subscribeErrorNotAnAddress(language)
        case .insecure: return L10n.subscribeErrorInsecure(language)
        case .alreadyFollowed: return L10n.subscribeErrorDuplicate(language)
        case .unreachable: return L10n.subscribeErrorUnreachable(language)
        case .unreadable: return L10n.subscribeErrorUnreadable(language)
        }
    }
}
