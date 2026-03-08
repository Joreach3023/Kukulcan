import Foundation

struct MapGenerator {
    private let rows: Int
    private let columns: Int

    private enum Config {
        static let startNodeCount = 3
        static let startNodeMinimumSpacing = 2
    }

    init(rows: Int = 15, columns: Int = 7) {
        self.rows = max(10, rows)
        self.columns = max(5, columns)
    }

    func generateActMap(seed: Int? = nil) -> MapGraph {
        var rng = SeededRandomNumberGenerator(seed: seed ?? Int.random(in: Int.min...Int.max))

        let adjacency = generateStructure(rng: &rng)
        let types = assignNodeTypes(adjacency: adjacency, rng: &rng)

        let rowToColumns = buildRowToColumns(from: adjacency)
        let startRow = 0
        let bossRow = rows - 1
        let startColumns = (rowToColumns[startRow]?.sorted() ?? []).prefix(Config.startNodeCount)
        let bossColumn = columns / 2

        var idsByPosition: [NodePosition: UUID] = [:]
        for (row, cols) in rowToColumns {
            for col in cols {
                idsByPosition[NodePosition(row: row, column: col)] = UUID()
            }
        }
        idsByPosition[NodePosition(row: bossRow, column: bossColumn)] = idsByPosition[NodePosition(row: bossRow, column: bossColumn)] ?? UUID()

        var nodes: [MapNode] = []
        for row in 0..<rows {
            let cols = rowToColumns[row]?.sorted() ?? []
            for col in cols {
                let position = NodePosition(row: row, column: col)
                guard let nodeID = idsByPosition[position] else { continue }
                let nextPositions = adjacency[position]?.sorted() ?? []
                let nextIDs = nextPositions.compactMap { idsByPosition[$0] }

                nodes.append(
                    MapNode(
                        id: nodeID,
                        row: row,
                        column: col,
                        type: types[position] ?? .combat,
                        nextNodeIDs: nextIDs,
                        isUnlocked: row == startRow,
                        isCompleted: false,
                        isDisabled: false
                    )
                )
            }
        }

        let bossID = idsByPosition[NodePosition(row: bossRow, column: bossColumn)] ?? UUID()
        let startNodeIDs = startColumns.compactMap { idsByPosition[NodePosition(row: startRow, column: $0)] }

        return MapGraph(nodes: nodes, startNodeIDs: startNodeIDs, bossNodeID: bossID)
    }

    private func generateStructure(rng: inout SeededRandomNumberGenerator) -> [NodePosition: Set<NodePosition>] {
        var edges: [NodePosition: Set<NodePosition>] = [:]
        let startColumns = spacedStartColumns(in: columns, rng: &rng)

        for startColumn in startColumns {
            var currentColumn = startColumn
            for row in 0..<(rows - 1) {
                let current = NodePosition(row: row, column: currentColumn)
                let move = [-1, 0, 1].randomElement(using: &rng) ?? 0
                let bias = biasTowardCenter(column: currentColumn)
                let adjustedMove = rng.nextDouble() < 0.35 ? bias : move
                let nextColumn = clamp(currentColumn + adjustedMove, min: 0, max: columns - 1)
                let next = NodePosition(row: row + 1, column: nextColumn)
                addEdge(from: current, to: next, into: &edges)

                if rng.nextDouble() < branchProbability(for: row) {
                    let branchMove = [-1, 1].randomElement(using: &rng) ?? 1
                    let branchColumn = clamp(currentColumn + branchMove, min: 0, max: columns - 1)
                    let branch = NodePosition(row: row + 1, column: branchColumn)
                    addEdge(from: current, to: branch, into: &edges)
                }

                currentColumn = nextColumn
            }
        }

        for row in 0..<(rows - 2) {
            let rowNodes = edges.keys.filter { $0.row == row }
            for node in rowNodes where (edges[node]?.isEmpty ?? true) {
                let nextColumn = clamp(node.column + ([-1, 0, 1].randomElement(using: &rng) ?? 0), min: 0, max: columns - 1)
                addEdge(from: node, to: NodePosition(row: row + 1, column: nextColumn), into: &edges)
            }
        }

        let bossPosition = NodePosition(row: rows - 1, column: columns / 2)
        let penultimate = edges.keys.filter { $0.row == rows - 2 }
        for node in penultimate {
            addEdge(from: node, to: bossPosition, into: &edges)
        }

        return edges
    }

    private func spacedStartColumns(in totalColumns: Int, rng: inout SeededRandomNumberGenerator) -> [Int] {
        let targetCount = min(Config.startNodeCount, totalColumns)
        let allColumns = Array(0..<totalColumns).shuffled(using: &rng)

        var selected: [Int] = []
        for column in allColumns {
            if selected.count == targetCount { break }
            if selected.allSatisfy({ abs($0 - column) >= Config.startNodeMinimumSpacing }) {
                selected.append(column)
            }
        }

        if selected.count < targetCount {
            for column in allColumns where !selected.contains(column) {
                if selected.count == targetCount { break }
                selected.append(column)
            }
        }

        return selected.sorted()
    }

    private func assignNodeTypes(
        adjacency: [NodePosition: Set<NodePosition>],
        rng: inout SeededRandomNumberGenerator
    ) -> [NodePosition: NodeType] {
        var result: [NodePosition: NodeType] = [:]

        let allNodes = Set(adjacency.keys).union(adjacency.values.flatMap { $0 })
        let sortedNodes = allNodes.sorted()
        let bossPosition = NodePosition(row: rows - 1, column: columns / 2)

        for node in sortedNodes {
            if node == bossPosition {
                result[node] = .boss
                continue
            }

            let progress = Double(node.row) / Double(max(1, rows - 1))
            var weighted = weightedTypes(for: progress)

            if node.row <= 1 {
                weighted = weighted.filter { $0.type != .elite }
            }

            if let previousType = parentTypes(of: node, adjacency: adjacency, assigned: result).first {
                if previousType == .elite {
                    weighted = weighted.filter { $0.type != .elite }
                }
                if previousType == .shop {
                    weighted = weighted.filter { $0.type != .shop }
                }
                if previousType == .campfire {
                    weighted = weighted.filter { $0.type != .campfire }
                }
            }

            result[node] = pickWeightedType(from: weighted, rng: &rng) ?? .combat
        }

        enforceMinimums(on: &result, excluding: bossPosition, rng: &rng)
        return result
    }

    private func enforceMinimums(
        on assigned: inout [NodePosition: NodeType],
        excluding bossPosition: NodePosition,
        rng: inout SeededRandomNumberGenerator
    ) {
        let minimums: [(NodeType, Int)] = [
            (.shop, 1),
            (.campfire, 2),
            (.event, 2),
            (.elite, 1),
            (.treasure, 1)
        ]

        let mutableNodes = assigned.keys.filter { $0 != bossPosition && $0.row > 0 }
        for (type, minimum) in minimums {
            while assigned.values.filter({ $0 == type }).count < minimum {
                guard let candidate = mutableNodes
                    .filter({ assigned[$0] == .combat || assigned[$0] == .event })
                    .sorted(by: { abs($0.row - preferredRow(for: type)) < abs($1.row - preferredRow(for: type)) })
                    .first else { break }

                assigned[candidate] = type
            }
        }

        if let firstRowNodes = assigned.keys.filter({ $0.row == 1 }).first,
           assigned[firstRowNodes] == .elite {
            assigned[firstRowNodes] = .combat
        }

        if assigned.values.filter({ $0 == .elite }).isEmpty,
           let highNode = assigned.keys.filter({ $0.row > rows / 2 && $0 != bossPosition }).randomElement(using: &rng) {
            assigned[highNode] = .elite
        }
    }

    private func parentTypes(
        of child: NodePosition,
        adjacency: [NodePosition: Set<NodePosition>],
        assigned: [NodePosition: NodeType]
    ) -> [NodeType] {
        adjacency.compactMap { (parent, children) in
            guard children.contains(child) else { return nil }
            return assigned[parent]
        }
    }

    private func weightedTypes(for progress: Double) -> [(type: NodeType, weight: Double)] {
        if progress < 0.25 {
            return [
                (.combat, 0.55),
                (.event, 0.25),
                (.campfire, 0.12),
                (.shop, 0.08)
            ]
        }
        if progress < 0.65 {
            return [
                (.combat, 0.4),
                (.event, 0.2),
                (.campfire, 0.15),
                (.shop, 0.1),
                (.treasure, 0.1),
                (.elite, 0.05)
            ]
        }

        return [
            (.combat, 0.32),
            (.event, 0.12),
            (.campfire, 0.16),
            (.shop, 0.08),
            (.treasure, 0.1),
            (.elite, 0.22)
        ]
    }

    private func pickWeightedType(
        from weighted: [(type: NodeType, weight: Double)],
        rng: inout SeededRandomNumberGenerator
    ) -> NodeType? {
        let total = weighted.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }

        let target = rng.nextDouble(in: 0...total)
        var cumulative = 0.0
        for entry in weighted {
            cumulative += entry.weight
            if target <= cumulative {
                return entry.type
            }
        }
        return weighted.last?.type
    }

    private func preferredRow(for type: NodeType) -> Int {
        switch type {
        case .elite: return Int(Double(rows) * 0.75)
        case .shop: return Int(Double(rows) * 0.45)
        case .campfire: return Int(Double(rows) * 0.6)
        case .event: return Int(Double(rows) * 0.35)
        case .treasure: return Int(Double(rows) * 0.55)
        case .combat: return Int(Double(rows) * 0.3)
        case .boss: return rows - 1
        }
    }

    private func buildRowToColumns(from adjacency: [NodePosition: Set<NodePosition>]) -> [Int: Set<Int>] {
        var output: [Int: Set<Int>] = [:]
        for (source, targets) in adjacency {
            output[source.row, default: []].insert(source.column)
            for target in targets {
                output[target.row, default: []].insert(target.column)
            }
        }
        return output
    }

    private func addEdge(from: NodePosition, to: NodePosition, into edges: inout [NodePosition: Set<NodePosition>]) {
        edges[from, default: []].insert(to)
    }

    private func branchProbability(for row: Int) -> Double {
        switch row {
        case 0: return 0
        case 1...3: return 0.2
        case 4...8: return 0.26
        default: return 0.18
        }
    }

    private func biasTowardCenter(column: Int) -> Int {
        let center = columns / 2
        if column < center { return 1 }
        if column > center { return -1 }
        return 0
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}

private struct NodePosition: Hashable, Comparable {
    let row: Int
    let column: Int

    static func < (lhs: NodePosition, rhs: NodePosition) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.column < rhs.column
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        let mixed = UInt64(bitPattern: Int64(seed))
        self.state = mixed == 0 ? 0x9E3779B97F4A7C15 : mixed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }

    mutating func nextDouble() -> Double {
        Double(next()) / Double(UInt64.max)
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextDouble()
    }
}
