//
//  LowShortcutApp.swift
//  LowShortcut
//
//  Created by Nils Bergmann on 13/06/2022.
//

import SwiftUI
import ShortcutRecorder
import Socket

@main
struct LowShortcutApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
              EmptyView()
            }
            .hidden()
            .onAppear {
//                DispatchQueue(label: "yabai-test").async {
//                    try? self.test()
//                }
            }
        }
    }
    
//    func test() throws {
//        let start = CFAbsoluteTimeGetCurrent()
//
//        let socket = try Socket.create(family: .unix, proto: .unix)
//
//        try socket.connect(to: "/tmp/yabai_nilsbergmann.socket")
//
//        let args = ["query", "--displaysss"]
//
//        var data = Data()
//
//        for arg in args {
//            guard var str = arg.data(using: .ascii) else {
//                return
//            }
//            str.append(0)
//            data.append(str)
//        }
//
//        try socket.write(from: data)
//
//        try! socket.setReadTimeout(value: 100)
//
//        shutdown(socket.socketfd, SHUT_WR);
//
//        var read = 0
//        var outputBuffer = NSMutableData()
//        var dataBuffer = Data()
//
//        repeat {
//            read = try! socket.read(into: outputBuffer)
//
//            dataBuffer.append(outputBuffer as Data)
//
//            outputBuffer = NSMutableData()
//        } while (read > 0)
//
//        let failureCode = "\u{07}";
//
//        let firstUnicodeCharacter = String(data: Data([dataBuffer[0]]), encoding: .utf8);
//
//        if failureCode == firstUnicodeCharacter {
//            print("Failure")
//        }
//
//        print("First: \(firstUnicodeCharacter)")
//
//        if let outputStr = String(data: dataBuffer, encoding: .utf8) {
//            print("str=\(outputStr)")
//        }
//
//        socket.close()
//
//        let diff = CFAbsoluteTimeGetCurrent() - start
//
//        print("Socket closed: \(diff)")
//    }
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
