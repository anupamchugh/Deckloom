# Deckloom

A small SwiftUI package for cards stacked like photos on a desk. You supply the card view; Deckloom handles the stacking, swiping, fanning and opening. iOS 17+, macOS 14+, visionOS 1+. No dependencies.

> Screenshots and a GIF are not included yet: they need a simulator or a demo app, and this package has neither.

## Modes

| Mode | What you see | Views |
| --- | --- | --- |
| Stack | Cards z-stacked with a slight tilt. Swipe sideways to snap to the next card; tap a neighbor to bring it forward. | `Deckloom` |
| Fan | The same cards spread out like a hand of cards. | `Deckloom` with `isFanned: true` |
| Open full screen | Tap the front card and it grows out of the stack to fill the screen. Tap it or swipe down to close. | `Deckloom` and `DeckloomOpenedCard` |
| Pile | A small rotated pile in a corner with a count badge. Tap it and the cards fly out into a deck you browse one at a time: tap the right side for the next card, the left third for the previous one. Progress bars sit at the top, and your own buttons sit under the card. | `DeckloomPile` and `DeckloomPileDeck` |

In every mode you own the state: the selection, `isFanned`, `opened` or `isOpen`. Each item needs a stable, unique `Identifiable.id`. A nil or missing selection shows the first card.

## Stack, fan and open full screen

```swift
import Deckloom

@State private var selected: Photo.ID?
@State private var fanned = false
@State private var opened: Photo.ID?
@Namespace private var deck

ScrollView {
    Deckloom(photos, selection: $selected, isFanned: $fanned, opened: $opened, namespace: deck) { photo in
        PhotoCard(photo: photo)
    }
    .frame(height: 340)
    Button(fanned ? "Stack" : "Fan out") { fanned.toggle() }
}
.overlay {
    DeckloomOpenedCard(photos, opened: $opened, namespace: deck) { photo in
        PhotoCard(photo: photo)
    }
}
```

Give the deck a bounded frame. A swipe or a tap on a neighbor writes the new ID back to the selection. Leave out `opened` to turn opening off. Up to three neighbors on each side are drawn.

A sideways drag changes cards, and a vertical drag that starts on a card still scrolls the container. On iOS 18 and later this uses a UIKit pan that refuses to start on vertical motion, because a SwiftUI drag inside a scroll view blocks scrolling. iOS 17, macOS and visionOS use a horizontal-only `DragGesture` that runs alongside the scroll.

## Pile

```swift
@State private var isOpen = false
@State private var current: Photo.ID?
@Namespace private var pile

InboxList()
    .overlay(alignment: .bottomTrailing) {
        DeckloomPile(newPhotos, isOpen: $isOpen, selection: $current, namespace: pile,
                     badge: { "\($0) new" },
                     actions: [DeckloomPileAction("Keep all", systemImage: "tray.and.arrow.down") { keepAll() }]) { photo in
            PhotoCard(photo: photo)
        }
        .padding()
    }
    .overlay {
        DeckloomPileDeck(newPhotos, isOpen: $isOpen, selection: $current, namespace: pile) { photo in
            PhotoCard(photo: photo)
        } accessory: { photo in
            HStack {
                Button("Keep") { keep(photo) }
                Button("Ask") { ask(about: photo) }
            }
        }
    }
```

- **Tap the pile** to open it. It shows the selected card and up to two after it. `size` sets the card size (72 × 96 points by default). `badge` sets the corner text; pass nil to hide it.
- **Long-press the pile** for your `DeckloomPileAction`s, such as "Keep all" or "Archive all". VoiceOver offers them as actions. Deckloom only calls your closure: it never deletes, hides, archives or sends anything itself.
- **In the opened deck**, tap the leading third to go back and the rest to go forward. Going forward from the last card closes the deck. Swiping sideways also changes cards, and swiping down, tapping the background or the close button closes it. Pass `showsProgress: false` to hide the progress bars. They only show where you are; nothing advances on a timer.
- **Haptics** use `sensoryFeedback`: a light impact when the pile opens or closes, and a selection tick when the card changes. Pass `haptics: false` to either view to turn them off. On visionOS they need visionOS 26.

## How the pile turns into a deck

Both views tag each card with `matchedGeometryEffect(id: item.id, in: namespace)`. When `isOpen` becomes true inside `withAnimation`, two things happen in the same transaction: the pile swaps its cards for empty placeholders, and the deck inserts the same IDs at full size. SwiftUI sees one view with an ID go away and another with that ID appear, so it animates the frame from the small pile position to the large deck position. To the person using the app, the cards fly out of the pile. Closing does the reverse: the deck goes away, and the pile draws the cards again starting at the current selection, so they fly back to where you left off.

```swift
// In the pile, closed:
card(item).frame(width: 72, height: 96).matchedGeometryEffect(id: item.id, in: namespace)
// In the deck, open:
card(item).frame(maxWidth: .infinity, maxHeight: .infinity).matchedGeometryEffect(id: item.id, in: namespace)
// The toggle:
withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { isOpen = true }
```

Only one view per ID is drawn at a time. That keeps exactly one source for each ID, which `matchedGeometryEffect` requires. Put `DeckloomPileDeck` and `DeckloomOpenedCard` outside any scroll view, for example in an `.overlay` on the screen, so they can fill it.

## Accessibility

- **VoiceOver:** the stack and the opened deck are adjustable, so swiping up or down moves between cards, and the value reads "Card 2 of 5". The stack has an Open action. The pile is a button labelled with its card count and offers the caller's actions. The opened card and the opened deck are modal and close with the escape gesture (two-finger scrub). The tap zones are hidden from VoiceOver, and the caller's accessory buttons stay reachable.
- **Reduce Motion:** the stack, fan and open animations are turned off. The pile and deck cross-fade (0.2 s) instead of flying, because `matchedGeometryEffect` is turned off.

## Design note: Instagram Instants

The pile is inspired by Instagram's Instants (launched 13 May 2026), which shows new photos as a small rotated pile in a corner of the inbox. Tap it and the photos open one at a time; hold it and swipe to snooze them. Deckloom keeps the good parts: the pile as a quiet doorway, and fast one-at-a-time browsing. It leaves out the rest. Nothing disappears after viewing, nothing is sent or shared, and no timer moves you on. Anything that changes data, such as keeping, archiving or asking, belongs to the app, through the actions and accessory views it supplies.

## Where it is used

- **Breakline:** the coach's photo deck for picked photos (merged 2 Nov 2026).
- **Planned:** Folio inbox triage (pile), the Screen Room poster shelf, Wardrobe looks, and Mirror Hand replays.

## Not included

Drag-to-reorder: iOS 27's `reorderable()` would need an iOS 27 availability branch, and its drag competes with the swipe that changes cards.

## Platforms and checks

iOS 17+, macOS 14+, visionOS 1+ (haptics need visionOS 26). Run `swift test` to check snapping, drag direction, selection fallback, tap behavior, fan placement, which cards the pile shows, the selection when opening, the tap zones, the progress bars, the selection carrying through opening and closing, and the Reduce Motion path. The stack, fan and open modes were checked in Breakline on an iPhone 17 Pro simulator (iOS 27.2). The pile has only been compiled for macOS, iOS and visionOS; it has not been run in an app, with VoiceOver, or on a device.
