//
//  LowShortcutApp.swift
//  LowShortcut
//
//  Created by Nils Bergmann on 13/06/2022.
//

import SwiftUI
import ShortcutRecorder

@main
struct LowShortcutApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
              EmptyView()
            }
            .hidden()
        }
    }
}


@MainActor
final class AppState: ObservableObject {
    let shortCutMonitor = AXGlobalShortcutMonitor(runLoop: RunLoop.main);
    
    let yabai = Yabai();
    let commandHandler: YabaiCommandHandler;
    
    init() {
        self.commandHandler = YabaiCommandHandler(yabai: self.yabai);
        
        var nonAxGlobalShortcut: GlobalShortcutMonitor? = GlobalShortcutMonitor.shared
                
        if let shortCutMonitor = nonAxGlobalShortcut {
                        
            shortCutMonitor.addAction(ShortcutAction(shortcut: Shortcut(keyEquivalent: "⌃⌘←")!) { _ in
                print("Exec BackSpaceAndMoveWindow")
                Task {
                    do {
                        try await self.commandHandler.addNextCommand(command: .BackSpaceAndMoveWindow)
                    } catch {
                        print("Error: \(error)")
                    }
                }
                return false
            }, forKeyEvent: .down);
            
            shortCutMonitor.addAction(ShortcutAction(shortcut: Shortcut(keyEquivalent: "⌃⌘→")!) { _ in
                print("Exec NextSpaceAndMoveWindow")
                Task {
                    do {
                        try await self.commandHandler.addNextCommand(command: .NextSpaceAndMoveWindow)
                    } catch {
                        print("Error: \(error)")
                    }
                }
                return false
            }, forKeyEvent: .down);
            
            shortCutMonitor.addAction(ShortcutAction(shortcut: Shortcut(keyEquivalent: "⌃→")!) { _ in
                print("Exec Next")
                Task {
                    do {
                        try await self.commandHandler.addNextCommand(command: .Next)
                    } catch {
                        print("Error: \(error)")
                    }
                }
                return false
            }, forKeyEvent: .down);
            shortCutMonitor.addAction(ShortcutAction(shortcut: Shortcut(keyEquivalent: "⌃←")!) { _ in
                print("Exec Back")
                Task {
                    do {
                        try await self.commandHandler.addNextCommand(command: .Back)
                    } catch {
                        print("Error: \(error)")
                    }
                }
                return false
            }, forKeyEvent: .down);
        }
    }
}
