# Blackjack Card Counter Trainer
### Educational Hi-Lo Card Counting App for iOS

---

## Quick Xcode Setup (one-shot to App Store)

### 1. Create the project
- Xcode → New Project → iOS → App
- Interface: **SwiftUI**, Language: **Swift**
- Product Name: `BlackjackTrainer`
- Bundle ID: `com.yourname.bjtrainer`
- Deployment target: **iOS 16.0**
- Uncheck "Include Tests"

### 2. Add the source file
- Delete `ContentView.swift` that Xcode generated
- Drag `BlackjackTrainer.swift` into the project navigator
- Make sure "Copy items if needed" is checked

### 3. Replace Info.plist
- Select the generated `Info.plist` in Xcode
- Replace its contents with the provided `Info.plist`
- OR: In project settings → Info tab, manually add:
  - `UISupportedInterfaceOrientations` = `[LandscapeLeft, LandscapeRight]`
  - `UIRequiresFullScreen` = `YES`

### 4. Wire up AppDelegate
In `BlackjackTrainerApp.swift` (or at the bottom of `BlackjackTrainer.swift`):
```swift
@main
struct BlackjackTrainerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```
The `AppDelegate` class is already defined at the bottom of `BlackjackTrainer.swift`.

### 5. Build and test
- Select iPhone 15 simulator
- Cmd+R to build
- Rotate simulator: Hardware → Rotate Left (Cmd+←)

---

## App Store Submission Checklist

### App Store Connect settings
- [ ] Category: **Education**
- [ ] Age Rating: **12+** (Simulated Gambling: No — this is educational, no real money)
- [ ] Privacy: No data collected (select "No" for all data types)

### App description (suggested)
```
Master the Hi-Lo card counting system used by professional blackjack players.

Blackjack Trainer is a comprehensive educational tool that teaches:
• The Hi-Lo card counting system (the same method used by MIT Blackjack Team)
• Perfect basic strategy for all hand combinations
• Illustrious 18 playing deviations based on true count
• Fab 4 surrender deviations
• Optimal bet sizing based on true count

Features:
• Realistic casino-style teal felt table
• Running count & true count display
• AI coach showing optimal play for every hand
• Card group guesser mini-game to sharpen your skills
• 1–8 deck shoe, 1–7 player seats
• Configurable penetration and dealer rules (H17/S17)
• Session statistics and edge estimate

For educational purposes only. Not for use in real casinos or gambling.
```

### Keywords (100 chars max)
```
blackjack,card counting,hi-lo,basic strategy,casino trainer,educational,card game,21
```

### Why it will get approved
1. Clearly educational — no real money, no IAP, no gambling mechanics
2. First-launch disclaimer shown to all users
3. No external network calls
4. Age 12+ rating (not 17+ gambling)
5. Privacy manifest: zero data collection

---

## Architecture Notes

### Files
- `BlackjackTrainer.swift` — entire app (1,670 lines, zero dependencies)
- `Info.plist` — landscape lock + App Store metadata

### Key components
| Component | Purpose |
|-----------|---------|
| `GameEngine` | `@MainActor ObservableObject` — shoe, counting, phase state |
| `BasicStrategy` | Complete S17 hard/soft/pair lookup tables |
| `DeviationTable` | Illustrious 18 + Fab 4 keyed to true count |
| `CardView` | Pure SwiftUI card rendering (no images needed) |
| `TableFeltView` | Canvas-drawn teal felt with oval and casino text |
| `CountHUDView` | Left panel: RC, TC, decks, penetration bar |
| `BetHUDView` | Right panel: bet suggestion, edge, W/L/P |
| `CoachPanelView` | Bottom: recommended action + deviation alert |
| `CardGuesserView` | Low/Mid/High/Skip guess mini-game |
| `OnboardingView` | 3-page swipeable onboarding (shows once) |
| `SettingsView` | Full settings sheet: decks, rules, toggles |

### Hi-Lo counting logic
```
2–6  → +1 (Low — added to running count)
7–9  → 0  (Neutral — ignored)
10/J/Q/K/A → -1 (High — subtracted)

Running Count = cumulative sum of all dealt cards
True Count = Running Count ÷ Decks Remaining
```

### Bet spread
| True Count | Bet |
|------------|-----|
| ≤ 0 | 1 unit (or sit out if TC ≤ -2) |
| +1 | 2 units |
| +2 | 4 units |
| +3 | 6 units |
| +4 | 8 units |
| ≥ +5 | MAX (12 units) |

---

## Extending the App

### Add sound effects
```swift
import AVFoundation
// Add card deal sound in dealCard()
AudioServicesPlaySystemSound(1104) // card flip sound
```

### Add haptic feedback
```swift
let impact = UIImpactFeedbackGenerator(style: .light)
impact.impactOccurred() // on each card deal
```

### Add a practice mode (no dealing, just count a stream of cards)
- Add `GamePhase.practice` 
- Deal cards one at a time without player actions
- Focus purely on running/true count tracking

### Add custom bet amounts
- Replace unit-based display with dollar amounts
- Add bankroll tracker to session stats
