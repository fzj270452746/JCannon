//
//  GameMode.swift
//  JCannon
//
//  How a play session is framed. The same ViewController drives every mode; the
//  mode only changes which blueprint it loads and what happens after a result.
//

import Foundation

enum GameMode: Equatable {
    /// Standard 300-stage campaign, advancing on win.
    case campaign
    /// Endless escalating rounds; a loss ends the run.
    case endless
    /// Today's seeded daily challenge; one attempt then back to menu.
    case daily
    /// Free play: pick your ammo, no win/loss pressure.
    case sandbox

    var title: String {
        switch self {
        case .campaign: return "CAMPAIGN"
        case .endless:  return "ENDLESS"
        case .daily:    return "DAILY"
        case .sandbox:  return "SANDBOX"
        }
    }
}
