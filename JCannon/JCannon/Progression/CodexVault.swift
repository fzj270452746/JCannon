//
//  CodexVault.swift
//  JCannon
//
//  The in-game encyclopedia. Entries for tiles, structures and bosses unlock the
//  first time the player encounters them, and persist. Descriptions are data so
//  the codex UI just renders what it's given.
//

import Foundation

/// A codex category for grouping in the UI.
enum CodexCategory: String, CaseIterable {
    case tiles = "TILES"
    case structures = "STRUCTURES"
    case bosses = "BOSSES"
    case mechanisms = "MECHANISMS"
}

/// A single encyclopedia entry.
struct CodexEntry {
    let id: String
    let category: CodexCategory
    let title: String
    let detail: String
}

/// Owns codex definitions + unlock state.
final class CodexVault {

    static let shared = CodexVault()

    let entries: [CodexEntry] = [
        // Tiles
        CodexEntry(id: "tile.redDragon", category: .tiles, title: "RED DRAGON",
                   detail: "Detonates on impact for radial explosion damage."),
        CodexEntry(id: "tile.greenDragon", category: .tiles, title: "GREEN DRAGON",
                   detail: "Emits a magnetic pulse that pulls nearby structures off balance."),
        CodexEntry(id: "tile.whiteDragon", category: .tiles, title: "WHITE DRAGON",
                   detail: "Releases a shock wave that shoves everything around it."),
        CodexEntry(id: "tile.wan", category: .tiles, title: "WAN",
                   detail: "The heaviest tile. Slow, but smashes towers with raw inertia."),
        CodexEntry(id: "tile.bamboo", category: .tiles, title: "BAMBOO",
                   detail: "The fastest tile with the lowest drag. Cuts straight through wind."),
        CodexEntry(id: "tile.dot", category: .tiles, title: "DOT",
                   detail: "Bounces up to three times — perfect for hidden switches."),
        // Structures
        CodexEntry(id: "struct.stoneTower", category: .structures, title: "STONE TOWER",
                   detail: "Sturdy stacked stone. Needs heavy hits or explosions."),
        CodexEntry(id: "struct.woodTower", category: .structures, title: "WOOD TOWER",
                   detail: "Light and brittle. Topples easily."),
        CodexEntry(id: "struct.dragonPillar", category: .structures, title: "DRAGON PILLAR",
                   detail: "Ornate segmented column crowned with gold."),
        CodexEntry(id: "struct.temple", category: .structures, title: "TEMPLE",
                   detail: "Pillars supporting a heavy roof slab. Knock out the legs."),
        CodexEntry(id: "struct.castle", category: .structures, title: "CASTLE",
                   detail: "A brick keep flanked by stone turrets."),
        CodexEntry(id: "struct.bridge", category: .structures, title: "BRIDGE",
                   detail: "A wooden deck on stone supports."),
        CodexEntry(id: "struct.floatingIsland", category: .structures, title: "FLOATING ISLAND",
                   detail: "A suspended platform carrying a small structure."),
        // Bosses
        CodexEntry(id: "boss.dragonStatue", category: .bosses, title: "DRAGON STATUE",
                   detail: "A towering idol with a rotating shield. Breaks in three phases."),
        // Mechanisms
        CodexEntry(id: "mech.spring", category: .mechanisms, title: "SPRING",
                   detail: "Flings any tile that lands on it high into the air."),
        CodexEntry(id: "mech.swingHammer", category: .mechanisms, title: "SWING HAMMER",
                   detail: "A pendulum that bats tiles off course. Time your shot."),
        CodexEntry(id: "mech.portal", category: .mechanisms, title: "PORTAL",
                   detail: "Enter one ring, exit the other with momentum intact."),
        CodexEntry(id: "mech.rope", category: .mechanisms, title: "ROPE",
                   detail: "Sever it and everything it holds comes crashing down."),
        CodexEntry(id: "mech.ice", category: .mechanisms, title: "ICE",
                   detail: "Low-friction ground. Structures slide and topple more easily."),
        CodexEntry(id: "mech.tnt", category: .mechanisms, title: "TNT BARREL",
                   detail: "Explodes violently when struck. Chain them for big damage.")
    ]

    private let defaults = UserDefaults.standard
    private let key = "jc.codex.unlocked"
    private(set) var unlocked: Set<String>

    private init() {
        unlocked = Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Marks an entry seen; emits a signal on first unlock.
    func discover(_ id: String) {
        guard !unlocked.contains(id) else { return }
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        unlocked.insert(id)
        defaults.set(Array(unlocked), forKey: key)
        CannonSignals.shared.emit(.codexEntryUnlocked(title: entry.title))
    }

    /// Convenience discovery hooks used by gameplay.
    func discoverTile(_ kind: TileKind) { discover("tile.\(kind.rawValue)") }
    func discoverStructure(_ kind: StructureKind) { discover("struct.\(kind.rawValue)") }
    func discoverBoss() { discover("boss.dragonStatue") }
    func discoverMechanism(_ kind: MechanismKind) { discover("mech.\(kind.rawValue)") }

    func isUnlocked(_ entry: CodexEntry) -> Bool { unlocked.contains(entry.id) }

    func entries(in category: CodexCategory) -> [CodexEntry] {
        entries.filter { $0.category == category }
    }
}
