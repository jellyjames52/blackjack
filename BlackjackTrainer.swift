import SwiftUI
import Foundation

// MARK: - Models

enum Suit: String, CaseIterable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"
    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum Rank: Int, CaseIterable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    var display: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }

    var value: Int {
        switch self {
        case .ace: return 11
        case .jack, .queen, .king: return 10
        default: return rawValue
        }
    }

    var hiLoValue: Int {
        switch self {
        case .two, .three, .four, .five, .six: return 1
        case .seven, .eight, .nine: return 0
        case .ten, .jack, .queen, .king, .ace: return -1
        }
    }

    var countGroup: String {
        switch self {
        case .two, .three, .four, .five, .six: return "2–6 (Low)"
        case .seven, .eight, .nine: return "7–9 (Mid)"
        case .ten, .jack, .queen, .king, .ace: return "10–A (High)"
        }
    }
}

struct Card: Identifiable {
    let id = UUID()
    let rank: Rank
    let suit: Suit
    var isFaceUp: Bool = true

    var value: Int { rank.value }
    var hiLoValue: Int { rank.hiLoValue }
}

struct Hand: Identifiable {
    let id = UUID()
    var cards: [Card] = []
    var isStood = false
    var isBust = false
    var isBlackjack = false
    var isSurrendered = false

    var total: Int {
        var sum = cards.filter(\.isFaceUp).reduce(0) { $0 + $1.value }
        var aces = cards.filter(\.isFaceUp).filter { $0.rank == .ace }.count
        while sum > 21 && aces > 0 {
            sum -= 10
            aces -= 1
        }
        return sum
    }

    var isSoft: Bool {
        let hasAce = cards.filter(\.isFaceUp).contains { $0.rank == .ace }
        if !hasAce { return false }
        let hardSum = cards.filter(\.isFaceUp).reduce(0) { $0 + ($1.rank == .ace ? 1 : $1.value) }
        return hardSum + 10 <= 21
    }

    var isPair: Bool {
        cards.count == 2 && cards[0].rank.value == cards[1].rank.value
    }

    var statusText: String {
        if isSurrendered { return "Surrender" }
        if isBlackjack { return "Blackjack!" }
        if isBust { return "Bust" }
        if isStood { return "Stand" }
        return "\(total)"
    }
}

enum GameAction: String {
    case hit = "Hit"
    case stand = "Stand"
    case double = "Double"
    case split = "Split"
    case surrender = "Surrender"
    case insurance = "Insurance"
}

enum GamePhase {
    case waiting, dealing, playerTurn, dealerTurn, roundOver, shuffling
}

// MARK: - Basic Strategy Table

struct BasicStrategy {
    // Returns recommended action for hard totals
    // dealer upcard: 2,3,4,5,6,7,8,9,10,A (index 0–9)
    static let hardTable: [Int: [GameAction]] = [
        5:  [.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit],
        6:  [.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit],
        7:  [.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit],
        8:  [.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit,.hit],
        9:  [.hit,.double,.double,.double,.double,.hit,.hit,.hit,.hit,.hit],
        10: [.double,.double,.double,.double,.double,.double,.double,.double,.hit,.hit],
        11: [.double,.double,.double,.double,.double,.double,.double,.double,.double,.hit],
        12: [.hit,.hit,.stand,.stand,.stand,.hit,.hit,.hit,.hit,.hit],
        13: [.stand,.stand,.stand,.stand,.stand,.hit,.hit,.hit,.hit,.hit],
        14: [.stand,.stand,.stand,.stand,.stand,.hit,.hit,.hit,.hit,.hit],
        15: [.stand,.stand,.stand,.stand,.stand,.hit,.hit,.hit,.surrender,.hit],
        16: [.stand,.stand,.stand,.stand,.stand,.hit,.hit,.surrender,.surrender,.surrender],
        17: [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand],
        18: [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand],
        19: [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand],
        20: [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand],
        21: [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand]
    ]

    // Soft totals keyed by non-ace card value (e.g. soft 17 = A+6, key=6)
    static let softTable: [Int: [GameAction]] = [
        2:  [.hit,.hit,.hit,.double,.double,.hit,.hit,.hit,.hit,.hit],    // A+2 = soft 13
        3:  [.hit,.hit,.hit,.double,.double,.hit,.hit,.hit,.hit,.hit],    // A+3 = soft 14
        4:  [.hit,.hit,.double,.double,.double,.hit,.hit,.hit,.hit,.hit], // A+4 = soft 15
        5:  [.hit,.hit,.double,.double,.double,.hit,.hit,.hit,.hit,.hit], // A+5 = soft 16
        6:  [.hit,.double,.double,.double,.double,.hit,.hit,.hit,.hit,.hit], // A+6 = soft 17
        7:  [.stand,.double,.double,.double,.double,.stand,.stand,.hit,.hit,.hit], // A+7 = soft 18
        8:  [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand], // A+8 = soft 19
        9:  [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand]  // A+9 = soft 20
    ]

    // Pair splits keyed by card value
    static let pairTable: [Int: [GameAction]] = [
        2:  [.split,.split,.split,.split,.split,.split,.hit,.hit,.hit,.hit],
        3:  [.split,.split,.split,.split,.split,.split,.hit,.hit,.hit,.hit],
        4:  [.hit,.hit,.hit,.split,.split,.hit,.hit,.hit,.hit,.hit],
        5:  [.double,.double,.double,.double,.double,.double,.double,.double,.hit,.hit],
        6:  [.split,.split,.split,.split,.split,.hit,.hit,.hit,.hit,.hit],
        7:  [.split,.split,.split,.split,.split,.split,.hit,.hit,.hit,.hit],
        8:  [.split,.split,.split,.split,.split,.split,.split,.split,.split,.split],
        9:  [.split,.split,.split,.split,.split,.stand,.split,.split,.stand,.stand],
        10: [.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand,.stand],
        11: [.split,.split,.split,.split,.split,.split,.split,.split,.split,.split] // Aces
    ]

    static func dealerIndex(_ dealerValue: Int) -> Int {
        switch dealerValue {
        case 2: return 0
        case 3: return 1
        case 4: return 2
        case 5: return 3
        case 6: return 4
        case 7: return 5
        case 8: return 6
        case 9: return 7
        case 10: return 8
        default: return 9 // Ace
        }
    }

    static func recommendation(hand: Hand, dealerUpcard: Card, trueCount: Double, dealerHitsS17: Bool) -> (base: GameAction, deviation: GameAction?) {
        let dIdx = dealerIndex(dealerUpcard.rank == .ace ? 11 : dealerUpcard.value)
        let dVal = dealerUpcard.rank == .ace ? 11 : dealerUpcard.value

        // Check deviations first
        let deviation = DeviationTable.check(hand: hand, dealerValue: dVal, trueCount: trueCount)

        // Pair split check
        if hand.isPair && hand.cards.count == 2 {
            let pairVal = hand.cards[0].rank == .ace ? 11 : hand.cards[0].value
            let key = pairVal == 11 ? 11 : (pairVal > 10 ? 10 : pairVal)
            if let actions = pairTable[key] {
                return (actions[dIdx], deviation)
            }
        }

        // Soft hand
        if hand.isSoft {
            let nonAceVal = hand.cards.filter { $0.rank != .ace }.reduce(0) { $0 + ($1.value > 10 ? 10 : $1.value) }
            let clampedKey = max(2, min(9, nonAceVal == 0 ? 2 : nonAceVal))
            if let actions = softTable[clampedKey] {
                return (actions[dIdx], deviation)
            }
        }

        // Hard total
        let total = max(5, min(21, hand.total))
        if let actions = hardTable[total] {
            return (actions[dIdx], deviation)
        }

        return (.stand, deviation)
    }
}

// MARK: - Deviation Table (Illustrious 18 + Fab 4)

struct DeviationTable {
    static func check(hand: Hand, dealerValue: Int, trueCount: Double) -> GameAction? {
        let total = hand.total
        let tc = trueCount

        // Insurance (handled separately, not as a hand deviation)
        // Illustrious 18
        switch (total, dealerValue) {
        case (16, 10): return tc >= 0 ? .stand : nil
        case (15, 10): return tc >= 4 ? .stand : nil
        case (10, 10): return tc >= 4 ? .double : nil
        case (10, 11): return tc >= 3 ? .double : nil
        case (12, 3):  return tc >= 2 ? .stand : nil
        case (12, 2):  return tc >= 3 ? .stand : nil
        case (11, 11): return tc >= -1 ? .double : nil
        case (9, 2):   return tc >= 1 ? .double : nil
        case (9, 7):   return tc >= 3 ? .double : nil
        case (16, 9):  return tc >= 5 ? .stand : nil
        case (13, 2):  return tc <= -1 ? .hit : nil
        case (13, 3):  return tc <= -2 ? .hit : nil
        // Fab 4 surrenders
        case (14, 10): return tc >= 3 ? .surrender : nil
        case (15, 9):  return tc >= 2 ? .surrender : nil
        case (15, 11): return tc >= 1 ? .surrender : nil
        default: return nil
        }
    }

    static func deviationDescription(hand: Hand, dealerValue: Int, trueCount: Double) -> String? {
        guard let action = check(hand: hand, dealerValue: dealerValue, trueCount: trueCount) else { return nil }
        let total = hand.total
        switch (total, dealerValue) {
        case (16, 10): return "⚡ Deviation: Stand (TC ≥ 0)"
        case (15, 10): return "⚡ Deviation: Stand (TC ≥ +4)"
        case (10, 10): return "⚡ Deviation: Double (TC ≥ +4)"
        case (10, 11): return "⚡ Deviation: Double (TC ≥ +3)"
        case (12, 3):  return "⚡ Deviation: Stand (TC ≥ +2)"
        case (12, 2):  return "⚡ Deviation: Stand (TC ≥ +3)"
        case (11, 11): return "⚡ Deviation: Double (TC ≥ -1)"
        case (9, 2):   return "⚡ Deviation: Double (TC ≥ +1)"
        case (9, 7):   return "⚡ Deviation: Double (TC ≥ +3)"
        case (16, 9):  return "⚡ Deviation: Stand (TC ≥ +5)"
        case (13, 2):  return "⚡ Deviation: Hit (TC ≤ -1)"
        case (13, 3):  return "⚡ Deviation: Hit (TC ≤ -2)"
        case (14, 10): return "⚡ Deviation: Surrender (TC ≥ +3)"
        case (15, 9):  return "⚡ Deviation: Surrender (TC ≥ +2)"
        case (15, 11): return "⚡ Deviation: Surrender (TC ≥ +1)"
        default: return "⚡ Deviation: \(action.rawValue)"
        }
    }
}

// MARK: - Game Engine

@MainActor
class GameEngine: ObservableObject {
    @Published var shoe: [Card] = []
    @Published var dealerHand = Hand()
    @Published var playerHands: [Hand] = [Hand()]
    @Published var activeHandIndex = 0
    @Published var runningCount = 0
    @Published var phase: GamePhase = .waiting
    @Published var sessionWins = 0
    @Published var sessionLosses = 0
    @Published var sessionPushes = 0
    @Published var lastActionFeedback: String? = nil
    @Published var insuranceTaken = false
    @Published var showInsurancePrompt = false
    @Published var shuffleAnimation = false
    @Published var cardGuessResult: String? = nil
    @Published var pendingCardGuess: String? = nil
    @Published var guessCorrect = 0
    @Published var guessTotal = 0
    @Published var roundResult: String? = nil

    var deckCount: Int = 6
    var playerCount: Int = 1
    var penetrationPct: Double = 0.75
    var dealerHitsS17: Bool = false

    var cardsRemaining: Int { shoe.count }
    var decksRemaining: Double { Double(shoe.count) / 52.0 }

    var trueCount: Double {
        guard decksRemaining > 0 else { return Double(runningCount) }
        let raw = Double(runningCount) / decksRemaining
        return (raw * 2).rounded() / 2
    }

    var betSuggestion: (units: Int, text: String) {
        let tc = trueCount
        if tc <= -2 { return (1, "Sit out") }
        if tc <= 0  { return (1, "1 unit") }
        if tc <= 1  { return (2, "2 units") }
        if tc <= 2  { return (4, "4 units") }
        if tc <= 3  { return (6, "6 units") }
        if tc <= 4  { return (8, "8 units") }
        return (12, "MAX (12)")
    }

    var edgeEstimate: Double {
        // Rough edge: base house edge ~0.5%, +0.5% per TC
        -0.5 + (trueCount * 0.5)
    }

    var penetration: Double {
        let total = Double(deckCount * 52)
        let dealt = total - Double(cardsRemaining)
        return total > 0 ? dealt / total : 0
    }

    var activeHand: Hand? {
        guard activeHandIndex < playerHands.count else { return nil }
        return playerHands[activeHandIndex]
    }

    var coachRecommendation: (action: GameAction, deviationText: String?)? {
        guard phase == .playerTurn,
              let hand = activeHand,
              !hand.isStood, !hand.isBust,
              let upcard = dealerHand.cards.first(where: { $0.isFaceUp }) else { return nil }
        let (base, dev) = BasicStrategy.recommendation(hand: hand, dealerUpcard: upcard, trueCount: trueCount, dealerHitsS17: dealerHitsS17)
        let devText = dev != nil ? DeviationTable.deviationDescription(hand: hand, dealerValue: upcard.rank == .ace ? 11 : upcard.value, trueCount: trueCount) : nil
        let finalAction = dev ?? base
        return (finalAction, devText)
    }

    var shouldOfferInsurance: Bool {
        guard let upcard = dealerHand.cards.first(where: { $0.isFaceUp }) else { return false }
        return upcard.rank == .ace
    }

    var insuranceRecommendation: Bool { trueCount >= 3 }

    func buildShoe() {
        var cards: [Card] = []
        for _ in 0..<deckCount {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(rank: rank, suit: suit))
                }
            }
        }
        shoe = cards.shuffled()
        runningCount = 0
    }

    func dealCard(faceUp: Bool = true) -> Card? {
        guard !shoe.isEmpty else { return nil }
        var card = shoe.removeLast()
        card.isFaceUp = faceUp
        if faceUp {
            runningCount += card.hiLoValue
        }
        return card
    }

    func revealHoleCard() {
        if let idx = dealerHand.cards.firstIndex(where: { !$0.isFaceUp }) {
            dealerHand.cards[idx].isFaceUp = true
            runningCount += dealerHand.cards[idx].hiLoValue
        }
    }

    func startNewRound() {
        guard phase == .waiting || phase == .roundOver else { return }

        // Check if shuffle needed
        if Double(shoe.count) < Double(deckCount * 52) * (1 - penetrationPct) {
            Task { await shuffle() }
            return
        }

        dealerHand = Hand()
        playerHands = Array(repeating: Hand(), count: max(1, playerCount))
        activeHandIndex = 0
        insuranceTaken = false
        showInsurancePrompt = false
        roundResult = nil
        lastActionFeedback = nil
        phase = .dealing

        // Deal out
        for i in 0..<playerHands.count {
            if let c = dealCard() { playerHands[i].cards.append(c) }
        }
        if let c = dealCard() { dealerHand.cards.append(c) }
        for i in 0..<playerHands.count {
            if let c = dealCard() { playerHands[i].cards.append(c) }
        }
        if let c = dealCard(faceUp: false) { dealerHand.cards.append(c) }

        // Check blackjacks
        for i in 0..<playerHands.count {
            if playerHands[i].total == 21 && playerHands[i].cards.count == 2 {
                playerHands[i].isBlackjack = true
            }
        }

        // Insurance prompt
        if shouldOfferInsurance {
            showInsurancePrompt = true
            phase = .playerTurn
        } else {
            phase = .playerTurn
        }
    }

    func takeInsurance() {
        insuranceTaken = true
        showInsurancePrompt = false
        advanceIfNeeded()
    }

    func declineInsurance() {
        insuranceTaken = false
        showInsurancePrompt = false
        advanceIfNeeded()
    }

    func playerHit() {
        guard phase == .playerTurn, activeHandIndex < playerHands.count else { return }
        lastActionFeedback = nil
        if let card = dealCard() {
            playerHands[activeHandIndex].cards.append(card)
            if playerHands[activeHandIndex].total > 21 {
                playerHands[activeHandIndex].isBust = true
                advanceToNextHand()
            }
        }
    }

    func playerStand() {
        guard phase == .playerTurn, activeHandIndex < playerHands.count else { return }
        playerHands[activeHandIndex].isStood = true
        lastActionFeedback = nil
        advanceToNextHand()
    }

    func playerDouble() {
        guard phase == .playerTurn, activeHandIndex < playerHands.count,
              playerHands[activeHandIndex].cards.count == 2 else { return }
        if let card = dealCard() {
            playerHands[activeHandIndex].cards.append(card)
        }
        playerHands[activeHandIndex].isStood = true
        lastActionFeedback = nil
        advanceToNextHand()
    }

    func playerSplit() {
        guard phase == .playerTurn, activeHandIndex < playerHands.count,
              playerHands[activeHandIndex].isPair else { return }
        var newHand = Hand()
        let splitCard = playerHands[activeHandIndex].cards.removeLast()
        newHand.cards.append(splitCard)
        if let c1 = dealCard() { playerHands[activeHandIndex].cards.append(c1) }
        if let c2 = dealCard() { newHand.cards.append(c2) }
        playerHands.insert(newHand, at: activeHandIndex + 1)
        lastActionFeedback = nil
    }

    func playerSurrender() {
        guard phase == .playerTurn, activeHandIndex < playerHands.count else { return }
        playerHands[activeHandIndex].isSurrendered = true
        lastActionFeedback = nil
        advanceToNextHand()
    }

    func advanceToNextHand() {
        let next = activeHandIndex + 1
        if next < playerHands.count {
            activeHandIndex = next
        } else {
            runDealerTurn()
        }
    }

    func advanceIfNeeded() {
        // Move past blackjacks
        while activeHandIndex < playerHands.count && playerHands[activeHandIndex].isBlackjack {
            activeHandIndex += 1
        }
        if activeHandIndex >= playerHands.count {
            runDealerTurn()
        }
    }

    func runDealerTurn() {
        phase = .dealerTurn
        revealHoleCard()

        // Dealer draws
        let limit = dealerHitsS17 ? 17 : 17
        var dealerTotal = dealerHand.total
        var dealerSoft = dealerHand.isSoft

        while dealerTotal < limit || (dealerHitsS17 && dealerSoft && dealerTotal == 17) {
            if let card = dealCard() {
                dealerHand.cards.append(card)
            }
            dealerTotal = dealerHand.total
            dealerSoft = dealerHand.isSoft
        }

        evaluateRound()
    }

    func evaluateRound() {
        let dealerTotal = dealerHand.total
        let dealerBust = dealerTotal > 21

        var results: [String] = []
        for i in 0..<playerHands.count {
            let hand = playerHands[i]
            if hand.isSurrendered {
                results.append("Surrender")
                continue
            }
            if hand.isBust {
                sessionLosses += 1
                results.append("Bust — Loss")
                continue
            }
            if hand.isBlackjack && dealerTotal != 21 {
                sessionWins += 1
                results.append("Blackjack! 3:2 Win")
                continue
            }
            let pTotal = hand.total
            if dealerBust {
                sessionWins += 1
                results.append("Dealer bust — Win")
            } else if pTotal > dealerTotal {
                sessionWins += 1
                results.append("Win (\(pTotal) vs \(dealerTotal))")
            } else if pTotal == dealerTotal {
                sessionPushes += 1
                results.append("Push (\(pTotal))")
            } else {
                sessionLosses += 1
                results.append("Loss (\(pTotal) vs \(dealerTotal))")
            }
        }
        roundResult = results.joined(separator: " · ")
        phase = .roundOver
    }

    func shuffle() async {
        phase = .shuffling
        shuffleAnimation = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        buildShoe()
        shuffleAnimation = false
        phase = .waiting
    }

    func validateAction(_ action: GameAction) -> String? {
        guard let rec = coachRecommendation else { return nil }
        if action == rec.action { return "✓ Perfect play!" }
        return "✗ \(rec.action.rawValue) was recommended\(rec.deviationText != nil ? " (deviation)" : "")"
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card
    var small: Bool = false

    private var w: CGFloat { small ? 44 : 52 }
    private var h: CGFloat { small ? 62 : 72 }
    private var fontSize: CGFloat { small ? 11 : 13 }

    var body: some View {
        if card.isFaceUp {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 1)
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                VStack(spacing: 0) {
                    HStack {
                        VStack(spacing: 0) {
                            Text(card.rank.display)
                                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                                .foregroundColor(card.suit.isRed ? Color(hex: "#D42B2B") : Color(hex: "#1A1A1A"))
                            Text(card.suit.rawValue)
                                .font(.system(size: fontSize - 2))
                                .foregroundColor(card.suit.isRed ? Color(hex: "#D42B2B") : Color(hex: "#1A1A1A"))
                        }
                        Spacer()
                    }
                    .padding(.top, 3).padding(.horizontal, 4)

                    Spacer()

                    Text(card.suit.rawValue)
                        .font(.system(size: small ? 18 : 22))
                        .foregroundColor(card.suit.isRed ? Color(hex: "#D42B2B") : Color(hex: "#1A1A1A"))

                    Spacer()

                    HStack {
                        Spacer()
                        VStack(spacing: 0) {
                            Text(card.suit.rawValue)
                                .font(.system(size: fontSize - 2))
                                .foregroundColor(card.suit.isRed ? Color(hex: "#D42B2B") : Color(hex: "#1A1A1A"))
                            Text(card.rank.display)
                                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                                .foregroundColor(card.suit.isRed ? Color(hex: "#D42B2B") : Color(hex: "#1A1A1A"))
                        }
                        .rotationEffect(.degrees(180))
                    }
                    .padding(.bottom, 3).padding(.horizontal, 4)
                }
            }
            .frame(width: w, height: h)
        } else {
            CardBackView(small: small)
        }
    }
}

struct CardBackView: View {
    var small: Bool = false
    private var w: CGFloat { small ? 44 : 52 }
    private var h: CGFloat { small ? 62 : 72 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: "#1A3A6B"))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
            Canvas { ctx, size in
                let path = Path { p in
                    var x: CGFloat = 0
                    while x < size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        x += 6
                    }
                }
                ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                .padding(4)
        }
        .frame(width: w, height: h)
    }
}

// MARK: - Table Felt Background

struct TableFeltView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Felt base
                Color(hex: "#0B6B4B")

                // Vignette
                RadialGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.45)]),
                    center: .center,
                    startRadius: geo.size.width * 0.25,
                    endRadius: geo.size.width * 0.75
                )

                // Table oval arc
                Canvas { ctx, size in
                    let ovalRect = CGRect(
                        x: size.width * 0.08,
                        y: size.height * 0.05,
                        width: size.width * 0.84,
                        height: size.height * 0.88
                    )
                    let oval = Path(ellipseIn: ovalRect)
                    ctx.stroke(oval, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 2.5))

                    // Inner oval
                    let innerRect = CGRect(
                        x: ovalRect.minX + 8,
                        y: ovalRect.minY + 8,
                        width: ovalRect.width - 16,
                        height: ovalRect.height - 16
                    )
                    let inner = Path(ellipseIn: innerRect)
                    ctx.stroke(inner, with: .color(.white.opacity(0.08)), style: StrokeStyle(lineWidth: 1))
                }

                // Casino text overlay
                VStack(spacing: 4) {
                    Text("BLACKJACK PAYS 3 TO 2")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(2)
                    Text("DEALER MUST DRAW TO 16 AND STAND ON ALL 17s")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.5)
                    Text("INSURANCE PAYS 2 TO 1")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -geo.size.height * 0.08)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Count HUD (Left Side)

struct CountHUDView: View {
    @ObservedObject var engine: GameEngine
    @Binding var showCount: Bool

    var body: some View {
        VStack(spacing: 6) {
            if showCount {
                VStack(spacing: 2) {
                    Text("RC")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(engine.runningCount >= 0 ? "+" : "")\(engine.runningCount)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(engine.runningCount > 0 ? Color(hex: "#4AE87A") :
                                        engine.runningCount < 0 ? Color(hex: "#FF6B6B") : .white)
                        .animation(.spring(response: 0.3), value: engine.runningCount)
                    Divider().background(Color.white.opacity(0.2))
                    Text("TC")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    let tc = engine.trueCount
                    Text("\(tc >= 0 ? "+" : "")\(String(format: "%.1f", tc))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(tc > 1 ? Color(hex: "#4AE87A") :
                                        tc < -1 ? Color(hex: "#FF6B6B") : .white)
                    Divider().background(Color.white.opacity(0.2))
                    Text(String(format: "%.1f", engine.decksRemaining))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("decks")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                    Divider().background(Color.white.opacity(0.2))
                    // Penetration bar
                    VStack(spacing: 2) {
                        Text("PEN")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.5))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.15))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(engine.penetration > 0.7 ? Color(hex: "#FF6B6B") : Color(hex: "#4AE87A"))
                                    .frame(width: g.size.width * min(1, engine.penetration))
                            }
                        }
                        .frame(height: 6)
                        Text("\(Int(engine.penetration * 100))%")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            } else {
                Image(systemName: "eye.slash")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        )
        .frame(width: 68)
    }
}

// MARK: - Bet HUD (Right Side)

struct BetHUDView: View {
    @ObservedObject var engine: GameEngine
    @Binding var showCount: Bool

    var body: some View {
        VStack(spacing: 6) {
            if showCount {
                let bet = engine.betSuggestion
                VStack(spacing: 2) {
                    Text("BET")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(bet.text)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#3D2800").opacity(0.8)))

                    Divider().background(Color.white.opacity(0.2))

                    let edge = engine.edgeEstimate
                    Text("EDGE")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(edge >= 0 ? "+" : "")\(String(format: "%.1f", edge))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(edge > 0 ? Color(hex: "#4AE87A") : Color(hex: "#FF6B6B"))

                    Divider().background(Color.white.opacity(0.2))

                    Text("W/L/P")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.5))
                    HStack(spacing: 2) {
                        Text("\(engine.sessionWins)")
                            .foregroundColor(Color(hex: "#4AE87A"))
                        Text("/")
                            .foregroundColor(.white.opacity(0.4))
                        Text("\(engine.sessionLosses)")
                            .foregroundColor(Color(hex: "#FF6B6B"))
                        Text("/")
                            .foregroundColor(.white.opacity(0.4))
                        Text("\(engine.sessionPushes)")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .font(.system(size: 10, weight: .semibold))
                }
            } else {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        )
        .frame(width: 72)
    }
}

// MARK: - Coach Panel

struct CoachPanelView: View {
    @ObservedObject var engine: GameEngine

    var actionColor: Color {
        switch engine.coachRecommendation?.action {
        case .stand: return Color(hex: "#2ECC71")
        case .hit: return Color(hex: "#3498DB")
        case .double: return Color(hex: "#F39C12")
        case .split: return Color(hex: "#9B59B6")
        case .surrender: return Color(hex: "#E74C3C")
        default: return .white
        }
    }

    var body: some View {
        if let rec = engine.coachRecommendation {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if let devText = rec.deviationText {
                        Text(devText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#F39C12"))
                    }
                    HStack(spacing: 6) {
                        Text(rec.action.rawValue.uppercased())
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(actionColor)
                        if rec.deviationText != nil {
                            Text("(deviation)")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#F39C12").opacity(0.8))
                        }
                    }
                }
                if let feedback = engine.lastActionFeedback {
                    Divider().frame(height: 30).background(Color.white.opacity(0.2))
                    Text(feedback)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(feedback.hasPrefix("✓") ? Color(hex: "#4AE87A") : Color(hex: "#FF6B6B"))
                        .multilineTextAlignment(.leading)
                }

                // Insurance advice if prompt is showing
                if engine.showInsurancePrompt {
                    Divider().frame(height: 30).background(Color.white.opacity(0.2))
                    VStack(spacing: 2) {
                        Text("Insurance?")
                            .font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                        Text(engine.insuranceRecommendation ? "✓ Take it (TC≥+3)" : "✗ Decline (TC<+3)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(engine.insuranceRecommendation ? Color(hex: "#4AE87A") : Color(hex: "#FF6B6B"))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.7))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(actionColor.opacity(0.4), lineWidth: 1))
            )
        }
    }
}

// MARK: - Card Guesser

struct CardGuesserView: View {
    @ObservedObject var engine: GameEngine
    var onGuess: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Guess next:")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
            ForEach(["2–6", "7–9", "10–A", "?"], id: \.self) { label in
                Button {
                    onGuess(label)
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                        )
                }
            }
            if let result = engine.cardGuessResult {
                Text(result)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(result.hasPrefix("✓") ? Color(hex: "#4AE87A") : Color(hex: "#FF6B6B"))
            }
            Spacer()
            if engine.guessTotal > 0 {
                Text("Accuracy: \(Int(Double(engine.guessCorrect)/Double(engine.guessTotal)*100))%")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
    }
}

// MARK: - Dealer Zone

struct DealerZoneView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        VStack(spacing: 4) {
            Text("DEALER")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)

            HStack(spacing: -8) {
                ForEach(engine.dealerHand.cards) { card in
                    CardView(card: card, small: true)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .opacity))
                }
            }

            if engine.phase == .dealerTurn || engine.phase == .roundOver {
                let total = engine.dealerHand.total
                Text("\(total)\(total > 21 ? " — BUST" : "")")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(total > 21 ? Color(hex: "#FF6B6B") : .white)
            }
        }
    }
}

// MARK: - Player Hand View

struct PlayerHandView: View {
    let hand: Hand
    let isActive: Bool
    let index: Int
    let total: Int

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(hex: "#FFD700").opacity(0.7), lineWidth: 1.5)
                        .frame(width: max(70, CGFloat(hand.cards.count) * 34 + 24), height: 90)
                }
                HStack(spacing: -10) {
                    ForEach(hand.cards) { card in
                        CardView(card: card, small: true)
                            .transition(.scale(scale: 0.7).combined(with: .offset(x: -30)))
                    }
                }
                .padding(4)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hand.cards.count)

            // Status badge
            let statusText = hand.statusText
            let bgColor: Color = hand.isBust ? Color(hex: "#8B0000") :
                                 hand.isBlackjack ? Color(hex: "#7B5800") :
                                 hand.isStood ? Color(hex: "#1A3A1A") :
                                 hand.isSurrendered ? Color(hex: "#3A1A1A") :
                                 isActive ? Color(hex: "#0A2A4A") : Color.black.opacity(0.5)

            Text(statusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(bgColor))
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var engine: GameEngine
    @Binding var showCount: Bool
    @Binding var showCoach: Bool
    @Binding var showGuesser: Bool
    @Environment(\.dismiss) var dismiss

    @State private var deckCount: Int = 6
    @State private var playerCount: Int = 1
    @State private var penetration: Double = 75
    @State private var dealerH17: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("Shoe") {
                    Picker("Decks", selection: $deckCount) {
                        ForEach([1,2,4,6,8], id: \.self) { n in
                            Text("\(n) deck\(n == 1 ? "" : "s")").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Players at table")
                        Spacer()
                        Stepper("\(playerCount)", value: $playerCount, in: 1...7)
                    }

                    HStack {
                        Text("Penetration: \(Int(penetration))%")
                        Slider(value: $penetration, in: 60...85, step: 5)
                    }
                }

                Section("Rules") {
                    Toggle("Dealer hits soft 17 (H17)", isOn: $dealerH17)
                }

                Section("HUD & Coach") {
                    Toggle("Show count (RC / TC)", isOn: $showCount)
                    Toggle("Show AI coach", isOn: $showCoach)
                    Toggle("Show card guesser", isOn: $showGuesser)
                }

                Section("Session") {
                    HStack {
                        Text("Wins"); Spacer()
                        Text("\(engine.sessionWins)").foregroundColor(.green)
                    }
                    HStack {
                        Text("Losses"); Spacer()
                        Text("\(engine.sessionLosses)").foregroundColor(.red)
                    }
                    HStack {
                        Text("Pushes"); Spacer()
                        Text("\(engine.sessionPushes)").foregroundColor(.secondary)
                    }
                    if engine.guessTotal > 0 {
                        HStack {
                            Text("Guess accuracy"); Spacer()
                            Text("\(Int(Double(engine.guessCorrect)/Double(engine.guessTotal)*100))%")
                        }
                    }
                    Button("Reset session stats", role: .destructive) {
                        engine.sessionWins = 0
                        engine.sessionLosses = 0
                        engine.sessionPushes = 0
                        engine.guessCorrect = 0
                        engine.guessTotal = 0
                    }
                }

                Section("Reference: Hi-Lo System") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2–6 = +1 (Low cards)")
                            .foregroundColor(.green)
                        Text("7–9 = 0 (Neutral)")
                            .foregroundColor(.secondary)
                        Text("10/J/Q/K/A = -1 (High cards)")
                            .foregroundColor(.red)
                        Text("True Count = Running Count ÷ Decks Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .font(.system(size: 13, design: .monospaced))
                }

                Section("Bet Spread Guide") {
                    VStack(alignment: .leading, spacing: 3) {
                        betRow("TC ≤ 0", "1 unit (or sit out)")
                        betRow("TC +1", "2 units")
                        betRow("TC +2", "4 units")
                        betRow("TC +3", "6 units")
                        betRow("TC +4", "8 units")
                        betRow("TC ≥ +5", "MAX (12 units)")
                    }
                    .font(.system(size: 12, design: .monospaced))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        engine.deckCount = deckCount
                        engine.playerCount = playerCount
                        engine.penetrationPct = penetration / 100.0
                        engine.dealerHitsS17 = dealerH17
                        engine.buildShoe()
                        dismiss()
                    }
                }
            }
            .onAppear {
                deckCount = engine.deckCount
                playerCount = engine.playerCount
                penetration = engine.penetrationPct * 100
                dealerH17 = engine.dealerHitsS17
            }
        }
    }

    @ViewBuilder func betRow(_ tc: String, _ bet: String) -> some View {
        HStack {
            Text(tc).foregroundColor(.secondary)
            Spacer()
            Text(bet).foregroundColor(.primary)
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    let pages: [(title: String, body: String, icon: String)] = [
        (
            "Card Counting Trainer",
            "This app teaches the Hi-Lo card counting system used by professional blackjack players. It's a purely educational tool — not for gambling.",
            "graduationcap.fill"
        ),
        (
            "The Hi-Lo System",
            "Assign values to each card:\n\n2–6 = +1 (Low)\n7–9 = 0 (Neutral)\n10, J, Q, K, A = -1 (High)\n\nKeep a running count through the shoe. A positive count means more high cards remain — favorable for the player.",
            "123.rectangle.fill"
        ),
        (
            "True Count & Betting",
            "Divide the running count by decks remaining to get the True Count. Bet more when TC is high:\n\nTC +1 → 2 units\nTC +2 → 4 units\nTC +3 → 6 units\n\nThe AI Coach shows optimal basic strategy moves and deviations based on the true count.",
            "chart.line.uptrend.xyaxis"
        )
    ]

    var body: some View {
        ZStack {
            Color(hex: "#0B6B4B").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $page) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        VStack(spacing: 20) {
                            Image(systemName: pages[i].icon)
                                .font(.system(size: 52))
                                .foregroundColor(.white.opacity(0.9))

                            Text(pages[i].title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(pages[i].body)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 320)

                Spacer()

                VStack(spacing: 12) {
                    Text("For educational purposes only. Not for real gambling.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Text(page < pages.count - 1 ? "Next" : "Start Training")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#0B6B4B"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .simultaneousGesture(TapGesture().onEnded {
                        if page < pages.count - 1 { page += 1 }
                    })
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Shuffle Overlay

struct ShuffleOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(0))
                Text("Shuffling…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("New shoe being prepared")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#0D1B2A")))
        }
    }
}

// MARK: - Insurance Prompt

struct InsurancePromptView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        VStack(spacing: 8) {
            Text("Dealer shows Ace — Insurance?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text(engine.insuranceRecommendation ? "AI: Take it (True Count ≥ +3)" : "AI: Decline (True Count < +3)")
                .font(.system(size: 11))
                .foregroundColor(engine.insuranceRecommendation ? Color(hex: "#4AE87A") : Color(hex: "#FF6B6B"))
            HStack(spacing: 12) {
                Button("Take Insurance") {
                    engine.takeInsurance()
                }
                .buttonStyle(BJButtonStyle(color: Color(hex: "#2E7D32")))

                Button("Decline") {
                    engine.declineInsurance()
                }
                .buttonStyle(BJButtonStyle(color: Color(hex: "#6B1A1A")))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.8)))
    }
}

// MARK: - Action Buttons

struct ActionButtonsView: View {
    @ObservedObject var engine: GameEngine
    var showCoach: Bool

    var canDouble: Bool {
        guard let h = engine.activeHand else { return false }
        return h.cards.count == 2
    }

    var canSplit: Bool {
        guard let h = engine.activeHand else { return false }
        return h.isPair && h.cards.count == 2
    }

    var canSurrender: Bool {
        guard let h = engine.activeHand else { return false }
        return h.cards.count == 2
    }

    var body: some View {
        HStack(spacing: 8) {
            Button("Hit") {
                if showCoach { engine.lastActionFeedback = engine.validateAction(.hit) }
                engine.playerHit()
            }
            .buttonStyle(BJButtonStyle(color: Color(hex: "#1A5276")))

            Button("Stand") {
                if showCoach { engine.lastActionFeedback = engine.validateAction(.stand) }
                engine.playerStand()
            }
            .buttonStyle(BJButtonStyle(color: Color(hex: "#1E8449")))

            if canDouble {
                Button("Double") {
                    if showCoach { engine.lastActionFeedback = engine.validateAction(.double) }
                    engine.playerDouble()
                }
                .buttonStyle(BJButtonStyle(color: Color(hex: "#7D6608")))
            }

            if canSplit {
                Button("Split") {
                    if showCoach { engine.lastActionFeedback = engine.validateAction(.split) }
                    engine.playerSplit()
                }
                .buttonStyle(BJButtonStyle(color: Color(hex: "#6C3483")))
            }

            if canSurrender {
                Button("Surrender") {
                    if showCoach { engine.lastActionFeedback = engine.validateAction(.surrender) }
                    engine.playerSurrender()
                }
                .buttonStyle(BJButtonStyle(color: Color(hex: "#7B241C")))
            }
        }
    }
}

struct BJButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? color.opacity(0.6) : color)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Shoe Stack View

struct ShoeStackView: View {
    let penetration: Double
    let deckCount: Int

    var body: some View {
        VStack(spacing: 1) {
            Text("SHOE")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            ZStack {
                ForEach(0..<min(8, Int((1 - penetration) * Double(deckCount) * 2)), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#1A3A6B"))
                        .frame(width: 28, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                        .offset(x: CGFloat(i) * 0.5, y: -CGFloat(i) * 0.8)
                }
            }
            .frame(width: 36, height: 50)

            Text("\(Int((1 - penetration) * 100))%")
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.35))
        }
    }
}

// MARK: - Round Result Banner

struct RoundResultBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.75))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
            )
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject var engine = GameEngine()

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("showCount") private var showCount = true
    @AppStorage("showCoach") private var showCoach = true
    @AppStorage("showGuesser") private var showGuesser = false

    @State private var showSettings = false
    @State private var pendingGuess: String? = nil

    var body: some View {
        ZStack {
            // Felt background
            TableFeltView()

            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left HUD
                    CountHUDView(engine: engine, showCount: $showCount)
                        .padding(.leading, 6)
                        .frame(maxHeight: .infinity, alignment: .center)

                    // Main table area
                    VStack(spacing: 0) {
                        // Top bar
                        HStack {
                            Button {
                                showCount.toggle()
                            } label: {
                                Image(systemName: showCount ? "eye" : "eye.slash")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 14))
                            }

                            Spacer()

                            if engine.shuffleAnimation {
                                Text("Shuffling new shoe...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 6)

                        // Dealer zone
                        DealerZoneView(engine: engine)
                            .frame(maxHeight: geo.size.height * 0.28)
                            .padding(.top, 4)

                        Spacer()

                        // Insurance prompt
                        if engine.showInsurancePrompt {
                            InsurancePromptView(engine: engine)
                                .padding(.bottom, 4)
                        }

                        // Round result
                        if let result = engine.roundResult {
                            RoundResultBanner(text: result)
                                .padding(.bottom, 6)
                        }

                        // Coach panel
                        if showCoach {
                            CoachPanelView(engine: engine)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 4)
                        }

                        // Player hands
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(engine.playerHands.indices, id: \.self) { i in
                                PlayerHandView(
                                    hand: engine.playerHands[i],
                                    isActive: i == engine.activeHandIndex && engine.phase == .playerTurn,
                                    index: i,
                                    total: engine.playerHands[i].total
                                )
                            }
                        }
                        .padding(.bottom, 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.playerHands.count)

                        // Card guesser
                        if showGuesser && engine.phase == .playerTurn {
                            CardGuesserView(engine: engine) { guess in
                                pendingGuess = guess
                                engine.pendingCardGuess = guess
                                engine.cardGuessResult = nil
                            }
                        }

                        // Action buttons / Deal button
                        HStack(spacing: 12) {
                            if engine.phase == .playerTurn && !engine.showInsurancePrompt {
                                ActionButtonsView(engine: engine, showCoach: showCoach)
                            } else if engine.phase == .waiting || engine.phase == .roundOver {
                                Button(engine.phase == .roundOver ? "Next Round" : "Deal") {
                                    engine.startNewRound()
                                }
                                .buttonStyle(BJButtonStyle(color: Color(hex: "#1A5276")))
                                .font(.system(size: 15, weight: .bold))
                            } else if engine.phase == .dealing || engine.phase == .dealerTurn {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .padding(.bottom, 8)
                        .animation(.easeInOut(duration: 0.2), value: engine.phase)
                    }
                    .frame(maxWidth: .infinity)

                    // Right HUD + Shoe
                    VStack(spacing: 8) {
                        BetHUDView(engine: engine, showCount: $showCount)
                        ShoeStackView(penetration: engine.penetration, deckCount: engine.deckCount)
                    }
                    .padding(.trailing, 6)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }

            // Shuffle overlay
            if engine.shuffleAnimation {
                ShuffleOverlayView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            engine.buildShoe()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine, showCount: $showCount, showCoach: $showCoach, showGuesser: $showGuesser)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            ))
        }
        .animation(.easeInOut(duration: 0.3), value: engine.shuffleAnimation)
    }
}

// MARK: - App Entry

@main
struct BlackjackTrainerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Landscape Lock (AppDelegate approach)
// Add to your Info.plist:
// UISupportedInterfaceOrientations = [UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight]
// UIRequiresFullScreen = YES
// Add this class to enforce landscape:

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .landscape
    }
}
