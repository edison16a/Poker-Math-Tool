import SwiftUI

// MARK: - Card Data Model

enum Suit: String, CaseIterable {
    case clubs = "♣︎"
    case diamonds = "♦︎"
    case hearts = "♥︎"
    case spades = "♠︎"
}

enum Rank: String, CaseIterable {
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    case ace = "A"
}

struct Card: Identifiable {
    let id = UUID()
    var rank: Rank
    var suit: Suit
    
    var imageName: String {
        return "card_\(suit)_\(rank.rawValue)"
    }
}

// Custom Equatable so that two cards with the same rank and suit are considered equal
extension Card: Equatable {
    static func ==(lhs: Card, rhs: Card) -> Bool {
        return lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }
}

// MARK: - Helper Extensions & Functions

extension Rank {
    var value: Int {
        switch self {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }
}

func getDeck() -> [Card] {
    var deck = [Card]()
    for suit in Suit.allCases {
        for rank in Rank.allCases {
            deck.append(Card(rank: rank, suit: suit))
        }
    }
    return deck
}

/// Evaluates a 7-card hand and returns its best ranking as a string.
func evaluateHand(cards: [Card]) -> String {
    // Group by rank and suit.
    let rankCounts = Dictionary(grouping: cards, by: { $0.rank }).mapValues { $0.count }
    let suitCounts = Dictionary(grouping: cards, by: { $0.suit }).mapValues { $0.count }
    
    // Check for flush.
    let isFlush = suitCounts.values.contains(where: { $0 >= 5 })
    var flushCards: [Card] = []
    if isFlush, let flushSuit = suitCounts.first(where: { $0.value >= 5 })?.key {
        flushCards = cards.filter { $0.suit == flushSuit }
    }
    
    // Helper to check for a straight.
    func hasStraight(in cards: [Card]) -> (found: Bool, highest: Int) {
        let uniqueRanks = Set(cards.map { $0.rank.value })
        var values = Array(uniqueRanks)
        values.sort()
        // Allow Ace to be low by adding 1 if Ace is present.
        if values.contains(14) && !values.contains(1) {
            values.insert(1, at: 0)
            values.sort()
        }
        var consecutive = 1
        var highest = values.first ?? 0
        for i in 1..<values.count {
            if values[i] == values[i-1] + 1 {
                consecutive += 1
                if consecutive >= 5 {
                    highest = values[i]
                }
            } else {
                consecutive = 1
            }
        }
        return (consecutive >= 5, highest)
    }
    
    let (isStraight, straightHigh) = hasStraight(in: cards)
    var isStraightFlush = false
    var straightFlushHigh = 0
    if isFlush {
        let (sfFound, high) = hasStraight(in: flushCards)
        isStraightFlush = sfFound
        straightFlushHigh = high
    }
    
    // Count occurrences.
    let fourOfAKind = rankCounts.values.contains(4)
    let threeOfAKind = rankCounts.values.contains(3)
    let pairCount = rankCounts.values.filter { $0 == 2 }.count
    // Full House: at least one three-of-a-kind and either a pair or a second three-of-a-kind.
    let fullHouse = threeOfAKind && (pairCount > 0 || rankCounts.values.filter { $0 >= 3 }.count > 1)
    
    // Determine best hand.
    if isStraightFlush {
        // Check for Royal Flush: flush with 10, J, Q, K, A present.
        let flushRankValues = flushCards.map { $0.rank.value }
        if flushRankValues.contains(10) && flushRankValues.contains(11) &&
            flushRankValues.contains(12) && flushRankValues.contains(13) &&
            flushRankValues.contains(14) {
            return "Royal Flush"
        }
        return "Straight Flush"
    } else if fourOfAKind {
        return "Four of a Kind"
    } else if fullHouse {
        return "Full House"
    } else if isFlush {
        return "Flush"
    } else if isStraight {
        return "Straight"
    } else if threeOfAKind {
        return "Three of a Kind"
    } else if pairCount >= 2 {
        return "Two Pair"
    } else if pairCount == 1 {
        return "Pair"
    } else {
        return "High Card"
    }
}

// MARK: - Main App

@main
struct PokerOddsEVApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    
    @State private var holeCards: [Card] = [
        Card(rank: .ace, suit: .spades),
        Card(rank: .king, suit: .spades)
    ]
    
    @State private var communityCards: [Card?] = Array(repeating: nil, count: 5)
    
    @State private var potSize: String = "100"
    
    // Hand type probabilities
    @State private var probabilities: [String: Double] = [
        "High Card": 0.0,
        "Pair": 0.0,
        "Two Pair": 0.0,
        "Three of a Kind": 0.0,
        "Straight": 0.0,
        "Flush": 0.0,
        "Full House": 0.0,
        "Four of a Kind": 0.0,
        "Straight Flush": 0.0,
        "Royal Flush": 0.0
    ]
    
    // A timer to recalc probabilities every second
    @State private var timer: Timer? = nil
    
    private var expectedValue: Double {
        let cost = 20.0
        let pot = Double(potSize) ?? 0.0
        
        let pairOrBetterProb = probabilities["Pair"]!
            + probabilities["Two Pair"]!
            + probabilities["Three of a Kind"]!
            + probabilities["Straight"]!
            + probabilities["Flush"]!
            + probabilities["Full House"]!
            + probabilities["Four of a Kind"]!
            + probabilities["Straight Flush"]!
            + probabilities["Royal Flush"]!
        
        return pairOrBetterProb * pot - (1.0 - pairOrBetterProb) * cost
    }
    
    // MARK: - New Helper Function for Text Color
    /// Returns a Color that:
    ///  - 0% to 20%:      red → orange
    ///  - 20% to 50%:     orange → yellow
    ///  - 50% to 75%:     yellow → chartreuse
    ///  - 75% to 100%:    chartreuse → green
    /// Returns a Color that:
    ///   - 0..10%    → red .. orange (fold territory)
    ///   - 10..25%   → orange .. yellow (cautious)
    ///   - 25..40%   → yellow .. chartreuse (leaning better)
    ///   - 40..100%  → chartreuse .. green (quite good)
    private func colorForProbability(_ probability: Double) -> Color {
        // Clamp probability into [0, 1]
        let p = max(0, min(1, probability))
        
        switch p {
        case 0.0...0.10:
            // 0..10%: red (hue=0.00) → orange (hue=0.08)
            let fraction = p / 0.10
            let hueStart = 0.00
            let hueEnd   = 0.08
            let hue = hueStart + fraction * (hueEnd - hueStart)
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
            
        case 0.10...0.25:
            // 10..25%: orange (0.08) → yellow (0.17)
            let fraction = (p - 0.10) / 0.15
            let hueStart = 0.08
            let hueEnd   = 0.17
            let hue = hueStart + fraction * (hueEnd - hueStart)
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
            
        case 0.25...0.40:
            // 25..40%: yellow (0.17) → chartreuse (0.25)
            let fraction = (p - 0.25) / 0.15
            let hueStart = 0.17
            let hueEnd   = 0.25
            let hue = hueStart + fraction * (hueEnd - hueStart)
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
            
        case 0.40...1.0:
            // 40..100%: chartreuse (0.25) → green (0.33)
            let fraction = (p - 0.40) / 0.60
            let hueStart = 0.25
            let hueEnd   = 0.33
            let hue = hueStart + fraction * (hueEnd - hueStart)
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
            
        default:
            // Should never happen after clamp
            return .red
        }
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                Text("Poker Odds & EV Calculator")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 10)
                
                // MARK: - Hole Cards Section
                Group {
                    Text("Your Cards")
                        .font(.headline)
                    
                    HStack(spacing: 30) {
                        ForEach(0..<2) { index in
                            CardInputView(card: $holeCards[index])
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(16)
                
                // MARK: - Pot Input Section
                VStack(spacing: 10) {
                    Text("Pot Size")
                        .font(.headline)
                    
                    TextField("Enter Pot Size", text: $potSize)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                        .onChange(of: potSize) { _ in
                            recalculateProbabilities()
                        }
                }
                .padding()
                
                // MARK: - Community Cards Section
                Group {
                    Text("Community Cards")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        
                        // Row 1 (indices 0..2)
                        HStack(spacing: 10) {
                            ForEach(0..<3) { index in
                                CardInputView(
                                    card: Binding(
                                        get: { communityCards[index] ?? Card(rank: .ace, suit: .spades) },
                                        set: { newValue in
                                            communityCards[index] = newValue
                                            recalculateProbabilities()
                                        }
                                    ),
                                    isOptional: true
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Row 2 (indices 3..4)
                        HStack(spacing: 10) {
                            ForEach(3..<5) { index in
                                CardInputView(
                                    card: Binding(
                                        get: { communityCards[index] ?? Card(rank: .ace, suit: .spades) },
                                        set: { newValue in
                                            communityCards[index] = newValue
                                            recalculateProbabilities()
                                        }
                                    ),
                                    isOptional: true
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(16)
                
                // MARK: - Probabilities Section
                Group {
                    Text("Hand Probabilities")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(probabilities.keys.sorted(), id: \.self) { key in
                            HStack {
                                
                                Text("\(key):")
                                    .padding(4)
                                Spacer()
                                Text("\((probabilities[key] ?? 0.0) * 100, specifier: "%.2f")%")
                                    .padding(4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    // Here we set the text color based on the probability value.
                                    .foregroundColor(colorForProbability(probabilities[key] ?? 0.0))
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                
                // MARK: - EV Section
                Group {
                    Text("Expected Value")
                        .font(.headline)
                    
                    Text("$\(expectedValue, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.bottom, 40)
                
            }
            .padding(.horizontal)
            .foregroundColor(.white)
            // Recalc every second
            .onAppear {
                recalculateProbabilities()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    recalculateProbabilities()
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    // MARK: - Probability Recalculation with Simulation
    private func recalculateProbabilities() {
        DispatchQueue.global(qos: .userInitiated).async {
            
            let currentHoleCards = self.holeCards
            let activeCommunityCards = self.communityCards.compactMap { $0 }
            let missingCount = 5 - activeCommunityCards.count
            
            // Define the 10 hand types
            let handTypes = [
                "High Card", "Pair", "Two Pair", "Three of a Kind",
                "Straight", "Flush", "Full House", "Four of a Kind",
                "Straight Flush", "Royal Flush"
            ]
            
            // Prepare a dictionary to store counts
            var counts = Dictionary(uniqueKeysWithValues: handTypes.map { ($0, 0) })
            
            // If the board is fully known or over-filled, just evaluate once
            if missingCount <= 0 {
                let final7 = currentHoleCards + activeCommunityCards
                let finalRank = evaluateHand(cards: final7)
                for type in handTypes {
                    counts[type] = (type == finalRank) ? 1 : 0
                }
                
                // Probability is trivial: 100% for the final rank only
                let newProb = handTypes.reduce(into: [String: Double]()) { dict, type in
                    dict[type] = (type == finalRank) ? 1.0 : 0.0
                }
                
                DispatchQueue.main.async {
                    self.probabilities = newProb
                }
                return
            }
            
            // Remove known cards from the deck
            let fullDeck = getDeck()
            let knownCards = currentHoleCards + activeCommunityCards
            var availableDeck = fullDeck.filter { !knownCards.contains($0) }
            
            // If only 1 or 2 unknown community cards => do exact combination
            if missingCount <= 2 {
                // Combination approach:
                // Generate all possible ways to pick `missingCount` from `availableDeck`.
                
                func combinations<T>(_ source: [T], taking k: Int) -> [[T]] {
                    if k == 0 { return [[]] }
                    if k == source.count { return [source] }
                    if k > source.count { return [] }
                    
                    var result = [[T]]()
                    
                    func recurse(_ index: Int, _ chosen: [T]) {
                        let needed = k - chosen.count
                        let remaining = source.count - index
                        if needed == 0 {
                            result.append(chosen)
                            return
                        }
                        if needed > remaining { return }
                        
                        // pick current
                        var chosenWithCurrent = chosen
                        chosenWithCurrent.append(source[index])
                        recurse(index + 1, chosenWithCurrent)
                        
                        // skip current
                        recurse(index + 1, chosen)
                    }
                    
                    recurse(0, [])
                    return result
                }
                
                let allCombos = combinations(availableDeck, taking: missingCount)
                
                for combo in allCombos {
                    let final7 = currentHoleCards + activeCommunityCards + combo
                    let rank = evaluateHand(cards: final7)
                    counts[rank, default: 0] += 1
                }
                
                let total = allCombos.count
                var newProbabilities = [String: Double]()
                for type in handTypes {
                    newProbabilities[type] = Double(counts[type] ?? 0) / Double(total)
                }
                
                DispatchQueue.main.async {
                    self.probabilities = newProbabilities
                }
                
            } else {
                // For 3+ unknown cards => do a Monte Carlo approach
                // (We can do 10,000 random draws, or 50,000 if you’d like more accuracy.)
                let iterations = 10000
                var rng = SystemRandomNumberGenerator()
                
                for _ in 0..<iterations {
                    // Shuffle the deck or pick random cards
                    availableDeck.shuffle(using: &rng)
                    
                    // Take the first `missingCount` as the hypothetical community fill
                    let drawn = Array(availableDeck.prefix(missingCount))
                    let final7 = currentHoleCards + activeCommunityCards + drawn
                    let rank = evaluateHand(cards: final7)
                    counts[rank, default: 0] += 1
                }
                
                var newProbabilities = [String: Double]()
                for type in handTypes {
                    newProbabilities[type] = Double(counts[type] ?? 0) / Double(iterations)
                }
                
                DispatchQueue.main.async {
                    self.probabilities = newProbabilities
                }
            }
        }
        
        
    }


}

// MARK: - Card Input View

struct CardInputView: View {
    @Binding var card: Card
    var isOptional: Bool = false
    
    // Start OFF by default (so "None" is shown if optional)
    @State private var noCardSelected: Bool = true
    
    var body: some View {
        VStack(spacing: 5) {
            // Show "None" if noCardSelected && isOptional
            if isOptional && noCardSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: 100, height: 140)
                    .overlay(
                        Text("None")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    )
            } else {
                Image(card.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 140)
                    .shadow(radius: 5)
                    .padding(4)
            }
            
            // Toggle to activate/deactivate the card if it's optional
            if isOptional {
                Toggle("Active", isOn:
                    Binding<Bool>(
                        get: { !noCardSelected },
                        set: { newValue in
                            noCardSelected = !newValue
                        }
                    )
                )
                .labelsHidden()
                .tint(.blue)
            }
            
            // Suit picker
            Picker(selection: Binding(
                get: { card.suit },
                set: { newSuit in
                    card = Card(rank: card.rank, suit: newSuit)
                }
            ), label: Text("Suit")) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    Text(suit.rawValue).tag(suit)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isOptional && noCardSelected)
            .frame(width: 100)
            
            // Rank picker
            Picker(selection: Binding(
                get: { card.rank },
                set: { newRank in
                    card = Card(rank: newRank, suit: card.suit)
                }
            ), label: Text("Rank")) {
                ForEach(Rank.allCases, id: \.self) { rank in
                    Text(rank.rawValue).tag(rank)
                }
            }
            .pickerStyle(.menu)
            .disabled(isOptional && noCardSelected)
            
        }
        .frame(maxWidth: 140)
        .padding(6)
        .background(Color(.systemGray6).opacity(0.4))
        .cornerRadius(12)
        .onChange(of: noCardSelected) { newValue in
            // If "None" is selected, we leave the parent's binding as-is.
        }
    }
}
