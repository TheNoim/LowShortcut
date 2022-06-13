//
//  yabai-structs.swift
//  LowShortcut
//
//  Created by Nils Bergmann on 13/06/2022.
//

import Foundation

struct Window: Decodable {
    let id: Int;
    let grabbed: Bool;
    let space: Int;
    let display: Int;
    
    enum CodingKeys: String, CodingKey {
        case id
        case grabbed = "is-grabbed"
        case space
        case display
    }
}

struct Display: Decodable {
    let id: Int;
    let index: Int;
    let uuid: String;
}

struct Space: Decodable {
    let id: Int;
    let index: Int;
    let focused: Bool;
    let visible: Bool;
    
    enum CodingKeys: String, CodingKey {
        case id
        case index
        case focused = "has-focus"
        case visible = "is-visible"
    }
}
