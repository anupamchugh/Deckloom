# Deckloom

A small SwiftUI package for caller-styled cards stacked like photos on a desk: swipe to snap to the next card, fan them out on request, and tap the front card to open it full screen. iOS 17+, macOS 14+, visionOS 1+. No dependencies.

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

Each item must have a stable, unique `Identifiable.id`. The caller provides the card view, a bounded frame, and owns the selection, fan and opened state. A nil or missing selection displays the first card; a swipe or a tap on a neighbor writes its ID back. A tap on the front card sets `opened`; `DeckloomOpenedCard` grows it out of the deck with `matchedGeometryEffect` and closes on a tap or a downward swipe. Put the opened card outside any scroll view so it can fill the screen. Leave out `opened` to turn opening off.

Up to three neighbors on either side are displayed. VoiceOver users adjust the stack to change selection and use the Open action; the opened card is modal and closes with the escape gesture. Reduced Motion disables the selection, fan and open animations.

Drag-to-reorder is not included: iOS 27's `reorderable()` needs an iOS 27 availability branch, and its drag competes with the swipe that changes cards in a stacked deck.

Run `swift test` to check snapping, selection fallback, tap behavior and fan placement.
