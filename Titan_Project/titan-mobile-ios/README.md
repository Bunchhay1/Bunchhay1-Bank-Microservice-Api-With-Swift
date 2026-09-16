# titan-mobile-ios 📱

SwiftUI mobile client for the TITAN Mobile Banking platform.

## Setup
1. Open Xcode → **File > New > Project** → iOS App → SwiftUI
2. Name it `TitanMobile`, Bundle ID: `com.titan.mobile`
3. Delete the default `ContentView.swift` and `TitanMobileApp.swift`
4. Drag **all files** from this folder into the Xcode project (keep folder structure)
5. Build & Run on iPhone 15+ simulator

## Structure
```
TitanMobile/
├── TitanMobileApp.swift          ← @main entry point
├── Theme/
│   └── AppTheme.swift            ← Colors, gradients, fonts, view modifiers
├── Models/
│   └── Models.swift              ← BankUser, ServiceItem, Transaction, AppTab
└── Views/
    ├── HomeView.swift            ← Full home screen
    ├── ServiceGridView.swift     ← ★ Orange gradient Services section
    ├── RecentTransactionsView.swift
    ├── BottomTabBar.swift
    └── ContentView.swift
```

## Design Highlights — Services Section
| Feature | Detail |
|---|---|
| Header | Orange gradient (`#FF8C00 → #FF5500 → #FF3D00`) |
| Card border | Orange gradient stroke (2pt) |
| Card shadow | Orange-tinted glow shadow |
| Icons | Gradient-filled circles with glass shine |
| Press effect | Spring scale + haptic feedback |
| Tab bar Home | Orange active indicator |
| Font | SF Pro Rounded (`.design: .rounded`) |

## Color Tokens
```swift
Color.orangeStart   // #FF8C00
Color.orangeMid     // #FF6B00
Color.orangeEnd     // #FF4500
Color.orangeSoft    // #FFF3E6  (pale orange background)
AppGradient.orangeGrade  // full orange LinearGradient
```
