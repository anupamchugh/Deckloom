# Deckloom

A small SwiftUI package for caller-styled cards that snap on a swipe and fan out on request. iOS 17+, macOS 14+, visionOS 1+.

```swift
import Deckloom

@State private var selected: Photo.ID?
@State private var fanned = false

Deckloom(photos, selection: $selected, isFanned: $fanned) { photo in
    PhotoCard(photo: photo)
}
.frame(height: 340)
Button(fanned ? "Stack" : "Fan out") { fanned.toggle() }
```

Each item must have a stable, unique `Identifiable.id`. The caller provides the card view, a bounded frame, and owns the selection and fan control. A nil or missing selection displays the first card; a swipe or tap writes its ID back. Up to three neighbors on either side are displayed. VoiceOver users can adjust the stack to change selection. Reduced Motion disables selection and fan animations.

Run `swift test` to check the snap boundaries. This initial package has not yet been integrated into an app or verified with VoiceOver, pointer input, or on physical devices.
