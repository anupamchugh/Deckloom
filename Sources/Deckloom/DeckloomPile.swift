import SwiftUI

/// An action offered when someone long-presses a ``DeckloomPile``. Deckloom only calls it.
public struct DeckloomPileAction {
    let title: LocalizedStringKey
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void

    public init(_ title: LocalizedStringKey, systemImage: String, role: ButtonRole? = nil,
                action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }
}

/// A small rotated pile of cards that opens into ``DeckloomPileDeck``. The caller owns `isOpen` and the selection.
///
/// Tap the pile to open it. Long-press it for the caller's ``DeckloomPileAction``s.
public struct DeckloomPile<Item: Identifiable, Card: View>: View {
    private let items: [Item]
    @Binding private var isOpen: Bool
    @Binding private var selection: Item.ID?
    private let namespace: Namespace.ID
    private let size: CGSize
    private let badge: ((Int) -> String)?
    private let actions: [DeckloomPileAction]
    private let haptics: Bool
    private let card: (Item) -> Card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - namespace: Shared with ``DeckloomPileDeck`` so the cards fly out of the pile and back.
    ///   - size: The size of each card in the pile.
    ///   - badge: The corner badge's text for the number of cards, such as `{ "\($0) new" }`. Pass nil to hide it.
    ///   - actions: Offered on a long press and to VoiceOver. Leave empty for none.
    ///   - haptics: Plays feedback when the pile opens and closes.
    public init(_ items: [Item], isOpen: Binding<Bool>, selection: Binding<Item.ID?>, namespace: Namespace.ID,
                size: CGSize = CGSize(width: 72, height: 96), badge: ((Int) -> String)? = { "\($0)" },
                actions: [DeckloomPileAction] = [], haptics: Bool = true,
                @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self._isOpen = isOpen
        self._selection = selection
        self.namespace = namespace
        self.size = size
        self.badge = badge
        self.actions = actions
        self.haptics = haptics
        self.card = card
    }

    public var body: some View {
        let start = DeckSelection.index(of: selection, in: items.map(\.id))
        ZStack {
            ForEach(DeckPile.shown(items.map(\.id), from: selection), id: \.self) { index in
                let depth = index - start
                Group {
                    if isOpen {
                        Color.clear
                    } else {
                        card(items[index])
                            .frame(width: size.width, height: size.height)
                            .deckloomMatched(id: items[index].id, in: DeckMotion.flies(reduceMotion: reduceMotion) ? namespace : nil)
                    }
                }
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(DeckPile.rotation(depth: depth)))
                .offset(x: CGFloat(depth) * 3, y: CGFloat(depth) * -2)
                .zIndex(-Double(depth))
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .topTrailing) {
            if let badge, !items.isEmpty, !isOpen {
                Text(badge(items.count))
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint, in: Capsule())
                    .offset(x: 10, y: -8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .contextMenu {
            ForEach(actions.indices, id: \.self) { index in
                let item = actions[index]
                Button(item.title, systemImage: item.systemImage, role: item.role, action: item.action)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pile of \(items.count) cards")
        .accessibilityValue(badge?(items.count) ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, open)
        .accessibilityActions {
            ForEach(actions.indices, id: \.self) { index in
                Button(actions[index].title, action: actions[index].action)
            }
        }
        .accessibilityHidden(items.isEmpty)
        .modifier(DeckHaptic(enabled: haptics, kind: .open, trigger: isOpen))
    }

    private func open() {
        guard !items.isEmpty else { return }
        withAnimation(DeckMotion.animation(reduceMotion: reduceMotion)) {
            selection = DeckPile.openingSelection(selection, in: items.map(\.id))
            isOpen = true
        }
    }
}

/// The opened pile: one card at a time, filling the view it is placed on.
///
/// Tap the leading third to go back and the rest to go forward; forward from the last card closes.
/// Swipe sideways to change cards and down to close. Place it above the content that holds the
/// ``DeckloomPile``, for example in an `.overlay` outside a scroll view, and pass both the same namespace.
public struct DeckloomPileDeck<Item: Identifiable, Card: View, Accessory: View>: View {
    private let items: [Item]
    @Binding private var isOpen: Bool
    @Binding private var selection: Item.ID?
    private let namespace: Namespace.ID
    private let showsProgress: Bool
    private let haptics: Bool
    private let card: (Item) -> Card
    private let accessory: (Item) -> Accessory
    @State private var drag: CGFloat = 0
    @GestureState private var dragDown: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - showsProgress: Shows a Stories-style bar for each card.
    ///   - haptics: Plays feedback when the card changes.
    ///   - accessory: The caller's controls under the card, such as Keep and Ask buttons.
    public init(_ items: [Item], isOpen: Binding<Bool>, selection: Binding<Item.ID?>, namespace: Namespace.ID,
                showsProgress: Bool = true, haptics: Bool = true,
                @ViewBuilder card: @escaping (Item) -> Card,
                @ViewBuilder accessory: @escaping (Item) -> Accessory) {
        self.items = items
        self._isOpen = isOpen
        self._selection = selection
        self.namespace = namespace
        self.showsProgress = showsProgress
        self.haptics = haptics
        self.card = card
        self.accessory = accessory
    }

    private var current: Int {
        DeckSelection.index(of: selection, in: items.map(\.id))
    }

    public var body: some View {
        if isOpen, items.indices.contains(current) {
            ZStack {
                Color.black.opacity(0.85 * (1 - min(1, dragDown / 400)))
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        if showsProgress {
                            DeckProgress(count: items.count, current: current)
                        } else {
                            Spacer()
                        }
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    cards
                    accessory(items[current])
                }
                .padding()
                .offset(y: dragDown)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 12)
                .updating($dragDown) { value, state, _ in
                    if !DeckSelection.isHorizontal(value.translation) { state = max(0, value.translation.height) }
                }
                .onEnded { value in
                    if !DeckSelection.isHorizontal(value.translation), value.predictedEndTranslation.height > 160 { close() }
                })
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, close)
            .transition(.opacity)
            .modifier(DeckHaptic(enabled: haptics, kind: .page, trigger: current))
        }
    }

    private var cards: some View {
        ZStack {
            ForEach(DeckPile.shown(items.map(\.id), from: selection), id: \.self) { index in
                let depth = index - current
                card(items[index])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .deckloomMatched(id: items[index].id, in: DeckMotion.flies(reduceMotion: reduceMotion) ? namespace : nil)
                    .scaleEffect(1 - 0.04 * CGFloat(depth))
                    .rotationEffect(.degrees(DeckPile.rotation(depth: depth) / 2))
                    .offset(x: depth == 0 ? drag : 0)
                    .zIndex(-Double(depth))
                    .overlay {
                        if depth == 0 { DeckTapZones(back: { page(.leading) }, forward: { page(.trailing) }) }
                    }
                    .accessibilityHidden(depth != 0)
            }
        }
        .modifier(DeckSwipe(changed: { drag = $0 }, ended: { predicted in
            withAnimation(DeckMotion.animation(reduceMotion: reduceMotion)) {
                drag = 0
                select(DeckSelection.target(current: current, count: items.count,
                                            predictedTranslation: predicted, threshold: 80))
            }
        }))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cards")
        .accessibilityValue("Card \(current + 1) of \(items.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(current + 1)
            case .decrement: select(current - 1)
            @unknown default: break
            }
        }
    }

    private func page(_ zone: DeckPaging.Zone) {
        switch DeckPaging.tap(zone, current: current, count: items.count) {
        case .show(let index):
            withAnimation(DeckMotion.animation(reduceMotion: reduceMotion)) { select(index) }
        case .close:
            close()
        }
    }

    private func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selection = items[index].id
    }

    private func close() {
        withAnimation(DeckMotion.animation(reduceMotion: reduceMotion)) {
            isOpen = false
        }
    }
}

extension DeckloomPileDeck where Accessory == EmptyView {
    public init(_ items: [Item], isOpen: Binding<Bool>, selection: Binding<Item.ID?>, namespace: Namespace.ID,
                showsProgress: Bool = true, haptics: Bool = true,
                @ViewBuilder card: @escaping (Item) -> Card) {
        self.init(items, isOpen: isOpen, selection: selection, namespace: namespace,
                  showsProgress: showsProgress, haptics: haptics, card: card) { _ in EmptyView() }
    }
}

/// Invisible tap targets over the front card: the leading third goes back, the rest goes forward.
private struct DeckTapZones: View {
    let back: () -> Void
    let forward: () -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geometry.size.width * DeckPaging.leadingShare)
                    .onTapGesture(perform: back)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: forward)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DeckProgress: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(DeckPaging.isFilled(index, current: current) ? 1 : 0.35))
                    .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Sensory feedback, off when the caller says so. visionOS has it from visionOS 26.
private struct DeckHaptic<Trigger: Equatable>: ViewModifier {
    enum Kind { case open, page }
    let enabled: Bool
    let kind: Kind
    let trigger: Trigger

    func body(content: Content) -> some View {
        if enabled {
            if #available(iOS 17, macOS 14, visionOS 26, *) {
                content.sensoryFeedback(kind == .open ? .impact(weight: .light) : .selection, trigger: trigger)
            } else {
                content
            }
        } else {
            content
        }
    }
}

enum DeckPile {
    /// The indices in the pile: the selected card and up to two after it.
    static func shown<ID: Equatable>(_ ids: [ID], from selection: ID?, limit: Int = 3) -> Range<Int> {
        let start = DeckSelection.index(of: selection, in: ids)
        return start..<min(start + limit, ids.count)
    }

    /// Opening keeps a valid selection and otherwise starts at the first card, so both views agree.
    static func openingSelection<ID: Equatable>(_ selection: ID?, in ids: [ID]) -> ID? {
        ids.isEmpty ? selection : ids[DeckSelection.index(of: selection, in: ids)]
    }

    static func rotation(depth: Int) -> Double {
        [-3, 5, -8][min(max(depth, 0), 2)]
    }
}

enum DeckPaging {
    enum Zone: Equatable { case leading, trailing }
    enum Outcome: Equatable { case show(Int), close }

    static let leadingShare: CGFloat = 1.0 / 3

    /// Back stops at the first card; forward from the last card closes the deck.
    static func tap(_ zone: Zone, current: Int, count: Int) -> Outcome {
        switch zone {
        case .leading: .show(max(current - 1, 0))
        case .trailing: current + 1 < count ? .show(current + 1) : .close
        }
    }

    /// Cards already seen and the current card are filled.
    static func isFilled(_ index: Int, current: Int) -> Bool {
        index <= current
    }
}

enum DeckMotion {
    /// With Reduce Motion the cards cross-fade instead of flying between pile and deck.
    static func flies(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.86)
    }
}
