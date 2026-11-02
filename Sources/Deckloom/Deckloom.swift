import SwiftUI

/// A small, caller-styled collection of cards. The caller owns selection and presentation.
public struct Deckloom<Item: Identifiable, Card: View>: View {
    private let items: [Item]
    @Binding private var selection: Item.ID?
    @Binding private var isFanned: Bool
    private let card: (Item) -> Card
    @GestureState private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ items: [Item], selection: Binding<Item.ID?>, isFanned: Binding<Bool>,
                @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self._selection = selection
        self._isFanned = isFanned
        self.card = card
    }

    private var selectedIndex: Int {
        items.firstIndex { $0.id == selection } ?? 0
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = max(1, min(geometry.size.width * 0.68, 300))
            let height = max(1, geometry.size.height * 0.78)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let distance = index - selectedIndex
                    if abs(distance) <= 3 {
                        card(item)
                            .frame(width: width, height: height)
                            .rotationEffect(.degrees(isFanned ? Double(distance) * 7 : Double(distance) * 2))
                            .offset(x: CGFloat(distance) * (isFanned ? width * 0.32 : 13) + drag,
                                    y: CGFloat(abs(distance)) * (isFanned ? 12 : 5))
                            .zIndex(-Double(abs(distance)))
                            .contentShape(Rectangle())
                            .onTapGesture { select(index) }
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
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: isFanned)
    }

    private func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selection = items[index].id
    }
}

enum DeckSelection {
    static func target(current: Int, count: Int, predictedTranslation: CGFloat, threshold: CGFloat) -> Int {
        guard count > 0 else { return 0 }
        let step = predictedTranslation < -threshold ? 1 : predictedTranslation > threshold ? -1 : 0
        return min(max(current + step, 0), count - 1)
    }
}
