import SwiftUI

/// A small, caller-styled collection of cards. The caller owns selection, fan, and opening.
public struct Deckloom<Item: Identifiable, Card: View>: View {
    private let items: [Item]
    @Binding private var selection: Item.ID?
    @Binding private var isFanned: Bool
    @Binding private var opened: Item.ID?
    private let namespace: Namespace.ID?
    private let card: (Item) -> Card
    @GestureState private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - opened: Set to a card's ID when the front card is tapped. Leave it out to disable opening.
    ///   - namespace: Shared with ``DeckloomOpenedCard`` so the opened card grows out of the deck.
    public init(_ items: [Item], selection: Binding<Item.ID?>, isFanned: Binding<Bool>,
                opened: Binding<Item.ID?> = .constant(nil), namespace: Namespace.ID? = nil,
                @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self._selection = selection
        self._isFanned = isFanned
        self._opened = opened
        self.namespace = namespace
        self.card = card
    }

    private var selectedIndex: Int {
        DeckSelection.index(of: selection, in: items.map(\.id))
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = max(1, min(geometry.size.width * 0.68, 300))
            let height = max(1, geometry.size.height * 0.78)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let distance = index - selectedIndex
                    if abs(distance) <= 3 {
                        let placement = DeckPlacement(distance: distance, isFanned: isFanned, cardWidth: width)
                        Group {
                            if opened == item.id {
                                Color.clear
                            } else {
                                card(item).deckloomMatched(id: item.id, in: namespace)
                            }
                        }
                        .frame(width: width, height: height)
                        .rotationEffect(.degrees(placement.rotation))
                        .offset(x: placement.x + drag, y: placement.y)
                        .zIndex(placement.zIndex)
                        .contentShape(Rectangle())
                        .onTapGesture { tap(index) }
                        .accessibilityHidden(index != selectedIndex)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 12)
                .updating($drag) { value, state, _ in state = value.translation.width }
                .onEnded { value in
                    guard !items.isEmpty else { return }
                    select(DeckSelection.target(current: selectedIndex, count: items.count,
                                                predictedTranslation: value.predictedEndTranslation.width,
                                                threshold: max(50, width * 0.3)))
                })
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Card stack")
            .accessibilityValue(items.isEmpty ? "Empty" : "Card \(selectedIndex + 1) of \(items.count)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: select(selectedIndex + 1)
                case .decrement: select(selectedIndex - 1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: "Open") { open(selectedIndex) }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: isFanned)
    }

    private func tap(_ index: Int) {
        switch DeckSelection.tap(index, selected: selectedIndex) {
        case .select: select(index)
        case .open: open(index)
        }
    }

    private func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selection = items[index].id
    }

    private func open(_ index: Int) {
        guard items.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
            opened = items[index].id
        }
    }
}

/// The opened card, filling the view it is placed on. Tap or swipe down to close.
///
/// Place it above the content that holds the ``Deckloom``, for example in an `.overlay`
/// outside a scroll view, and pass both the same namespace.
public struct DeckloomOpenedCard<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    @Binding private var opened: Item.ID?
    private let namespace: Namespace.ID
    private let content: (Item) -> Content
    @GestureState private var dragDown: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ items: [Item], opened: Binding<Item.ID?>, namespace: Namespace.ID,
                @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self._opened = opened
        self.namespace = namespace
        self.content = content
    }

    public var body: some View {
        if let item = items.first(where: { $0.id == opened }) {
            ZStack {
                Color.black.opacity(0.85 * (1 - min(1, dragDown / 400)))
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)
                content(item)
                    .deckloomMatched(id: item.id, in: namespace)
                    .padding()
                    .offset(y: dragDown)
                    .onTapGesture(perform: close)
            }
            .gesture(DragGesture(minimumDistance: 12)
                .updating($dragDown) { value, state, _ in state = max(0, value.translation.height) }
                .onEnded { value in
                    if value.predictedEndTranslation.height > 160 { close() }
                })
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, close)
            .accessibilityAction(named: "Close", close)
            .transition(.opacity)
        }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
            opened = nil
        }
    }
}

private extension View {
    @ViewBuilder
    func deckloomMatched<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}

/// Where one card sits relative to the selected card.
struct DeckPlacement: Equatable {
    let rotation: Double
    let x: CGFloat
    let y: CGFloat
    let zIndex: Double

    init(distance: Int, isFanned: Bool, cardWidth: CGFloat) {
        rotation = Double(distance) * (isFanned ? 7 : 2)
        x = CGFloat(distance) * (isFanned ? cardWidth * 0.32 : 13)
        y = CGFloat(abs(distance)) * (isFanned ? 12 : 5)
        zIndex = -Double(abs(distance))
    }
}

enum DeckSelection {
    enum Tap: Equatable { case select, open }

    /// The displayed card: the selection's index, or the first card when the selection is nil or missing.
    static func index<ID: Equatable>(of selection: ID?, in ids: [ID]) -> Int {
        ids.firstIndex { $0 == selection } ?? 0
    }

    /// Tapping the front card opens it; tapping a neighbor brings it to the front.
    static func tap(_ index: Int, selected: Int) -> Tap {
        index == selected ? .open : .select
    }

    static func target(current: Int, count: Int, predictedTranslation: CGFloat, threshold: CGFloat) -> Int {
        guard count > 0 else { return 0 }
        let step = predictedTranslation < -threshold ? 1 : predictedTranslation > threshold ? -1 : 0
        return min(max(current + step, 0), count - 1)
    }
}
