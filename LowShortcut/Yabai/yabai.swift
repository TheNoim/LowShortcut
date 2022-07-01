//
//  yabai.swift
//  LowShortcut
//
//  Created by Nils Bergmann on 13/06/2022.
//

import Foundation
import AppKit
import SwiftSlash
import Socket

actor Yabai {
    var displayMouseQueryCache: [Space]?;
    
    let lock = NSLock()
    
    let failureCode = "\u{07}";
    
    func getDisplayMouseQueryCache() async throws -> [Space] {
        if self.displayMouseQueryCache != nil {
            return self.displayMouseQueryCache!;
        }
        
        let screen = getScreenWithMouse()
        if screen != nil {
            let display = try? await getDisplayByUUID(uuid: screen!.identifier);
            if display != nil {
                let jsonData = try await self.runYabaiCommand(arguments: ["-m", "query", "--spaces", "--display", "\(display!.index)"]);
                guard let decoded = try? JSONDecoder().decode([Space].self, from: jsonData) else {
                    throw MyError.runtimeError("Can not find current space for display. Can not parse json");
                }
                self.displayMouseQueryCache = decoded;
                return decoded;
            }
        }
        
        let jsonData = try await self.runYabaiCommand(arguments: ["-m", "query", "--spaces", "--display", "mouse"]);
        guard let decoded = try? JSONDecoder().decode([Space].self, from: jsonData) else {
            throw MyError.runtimeError("Can not find current space for display. Can not parse json");
        }
        self.displayMouseQueryCache = decoded;
        return decoded;
    }
    
    func runYabaiCommandOnSocket(arguments: [String]) async throws -> Data {
        return try await withCheckedThrowingContinuation({ continuation in
            DispatchQueue(label: "yabai").async {
                self.lock.lock()
                defer {
                    self.lock.unlock()
                }
                
                var newArguments = arguments
                
                // remove the -m
                newArguments.removeFirst()
                
                var payload = Data()

                for arg in newArguments {
                    guard var str = arg.data(using: .utf8) else {
                        return
                    }
                    str.append(0)
                    payload.append(str)
                }
                
                do {
                    let socket = try Socket.create(family: .unix, proto: .unix)
                    
                    defer {
                        socket.close()
                    }

                    let userName = NSUserName()
                    
                    try socket.connect(to: "/tmp/yabai_\(userName).socket")
                    
                    try socket.setReadTimeout(value: 100)
                    
                    try socket.write(from: payload)
                    
                    shutdown(socket.socketfd, SHUT_WR);
                    
                    var read = 0
                    var outputBuffer = NSMutableData()
                    var dataBuffer = Data()
                    
                    repeat {
                        read = try! socket.read(into: outputBuffer)
                        
                        dataBuffer.append(outputBuffer as Data)
                        
                        outputBuffer = NSMutableData()
                    } while (read > 0)
                    
                    if dataBuffer.count < 1 {
                        continuation.resume(returning: dataBuffer)
                        return
                    }
                    
                    let firstUnicodeCharacter = String(data: Data([dataBuffer[0]]), encoding: .utf8);
                    
                    guard let outputStr = String(data: dataBuffer, encoding: .utf8) else {
                        throw MyError.runtimeError("Invalid data returned my yabai")
                    }
                    
                    if self.failureCode == firstUnicodeCharacter {
                        throw MyError.runtimeError(outputStr)
                    }
                    
                    continuation.resume(returning: dataBuffer)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        })
    }
    
    func runYabaiCommand(arguments: [String]) async throws -> Data {
        return try await self.runYabaiCommandOnSocket(arguments: arguments);
        
        let command = try await Command(execute: "/usr/local/bin/yabai", arguments: arguments).runSync();
        
        if command.succeeded {
            return command.stdout.reduce(Data()) { partialResult, next in
                var current = partialResult;
                current.append(next)
                return current;
            }
        }
        
        let error = command.stderr.reduce("") { partialResult, next in
            return partialResult + (String(data: next, encoding: .utf8) ?? "")
        }
        
        print("Error: \(error)");
        
        throw MyError.runtimeError("Yabai exited with error code \(command.exitCode)")
    }
    
    func getCurrentDisplay() async throws -> Int {
        let jsonData = try await self.runYabaiCommand(arguments: ["-m", "query", "--displays", "--display", "mouse"]);
        guard let decoded = try? JSONDecoder().decode(Display.self, from: jsonData) else {
            throw MyError.runtimeError("Can not find current display. Can not parse json");
        }
        return decoded.index;
    }
    
    func getDisplayByUUID(uuid: String) async throws -> Display? {
        let jsonData = try await self.runYabaiCommand(arguments: ["-m", "query", "--displays"]);
        guard let decoded = try? JSONDecoder().decode([Display].self, from: jsonData) else {
            throw MyError.runtimeError("Can not find current display. Can not parse json");
        }
        return decoded.first { $0.uuid == uuid };
    }
    
    func getCurrentSpaceForDisplay() async throws -> Int {
        let decoded = try await self.getDisplayMouseQueryCache();
        return decoded.filter({ $0.visible || $0.focused }).first!.index;
    }
    
    func getFirstSpaceIndexForDisplay() async throws -> Int {
        let decoded = try await self.getDisplayMouseQueryCache();
        return decoded.first!.index;
    }
    
    func getLastSpaceIndexForDisplay() async throws -> Int {
        let decoded = try await self.getDisplayMouseQueryCache();
        return decoded.last!.index;
    }
    
    func getFocusedWindow() async throws -> Window {
        let jsonData = try await self.runYabaiCommand(arguments: ["-m", "query", "--windows", "--window"]);
        guard let decoded = try? JSONDecoder().decode(Window.self, from: jsonData) else {
            throw MyError.runtimeError("Can not find focused window. Can not parse json");
        }
        return decoded;
    }
    
    func focusSpace(index: Int) async throws {
        let _ = try await self.runYabaiCommand(arguments: ["-m", "space", "--focus", "\(index)"])
    }

    func moveWindowToSpace(windowIndex: Int, spaceIndex: Int) async throws {
        let _ = try await self.runYabaiCommand(arguments: ["-m", "window", "\(windowIndex)", "--space", "\(spaceIndex)"])
    }

    func focusWindow(index: Int) async throws {
        let _ = try await self.runYabaiCommand(arguments: ["-m", "window", "--focus", "\(index)"])
    }
    
    func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
        
        return screenWithMouse;
    }
    
    func getGrabbedWindow() async throws -> Int? {
        var grabbedIndex: Int?;
        
        if let jsonData = try? await self.runYabaiCommand(arguments: ["-m", "query", "--windows", "--window", "mouse"]) {
            let decoded = try JSONDecoder().decode(Window.self, from: jsonData);
            if decoded.grabbed {
                grabbedIndex = decoded.id;
            }
        }
        
        return grabbedIndex;
    }
    
    func getFocusedWindowForMove(currentSpace: Int) async throws -> Int? {
        async let currentDisplayTask = getCurrentDisplay();
        async let focusedWindowTask = getFocusedWindow();
        
        let results = try await [currentDisplayTask, focusedWindowTask] as [Any];
        
        guard let display = results[0] as? Int else {
            return nil;
        }
        guard let focusedWindow = results[1] as? Window else {
            return nil;
        }
        
        if focusedWindow.display == display && focusedWindow.space == currentSpace {
            return focusedWindow.id
        }
        return nil;
    }
    
    func next(moveWindow: Bool = false) async throws {
        let event = CGEvent(source: nil)
        
        // Start all maybe required tasks
        async let currentSpaceTask = getCurrentSpaceForDisplay();
        async let lastSpaceTask = getLastSpaceIndexForDisplay();
        async let firstSpaceTask = getFirstSpaceIndexForDisplay();
        
        // Fetch in parallel
        let tasks = try await [currentSpaceTask, lastSpaceTask];
        let currentSpace = tasks[0];
        let lastSpace = tasks[1];
        
        async let grabbedIndexTask = moveWindow ? getFocusedWindowForMove(currentSpace: currentSpace) : getGrabbedWindow();
        
        var targetSpaceIndex: Int = 0;
        
        if currentSpace == lastSpace {
            targetSpaceIndex = try await firstSpaceTask;
        } else {
            targetSpaceIndex = currentSpace + 1;
        }
        
        let grabbedIndex = try await grabbedIndexTask
        
        try await self.focusSpace(index: targetSpaceIndex);
        
        if grabbedIndex != nil {
            try await self.moveWindowToSpace(windowIndex: grabbedIndex!, spaceIndex: targetSpaceIndex);
            try await self.focusWindow(index: grabbedIndex!);
        }
        
        if event != nil {
            CGWarpMouseCursorPosition(event!.location);
        }
        
        self.clearCache()
    }
    
    func back(moveWindow: Bool = false) async throws {
        let event = CGEvent(source: nil)
        
        // Start all maybe required tasks
        async let currentSpaceTask = getCurrentSpaceForDisplay();
        async let lastSpaceTask = getLastSpaceIndexForDisplay();
        async let firstSpaceTask = getFirstSpaceIndexForDisplay();
                
        // Fetch in parallel
        let tasks = try await [currentSpaceTask, firstSpaceTask];
        let currentSpace = tasks[0];
        let firstSpace = tasks[1];
        
        async let grabbedIndexTask = moveWindow ? getFocusedWindowForMove(currentSpace: currentSpace) : getGrabbedWindow();
        
        var targetSpaceIndex: Int = 0;
        
        if currentSpace == firstSpace {
            targetSpaceIndex = try await lastSpaceTask;
        } else {
            targetSpaceIndex = currentSpace - 1;
        }
        
        let grabbedIndex = try await grabbedIndexTask
        
        try await self.focusSpace(index: targetSpaceIndex);
        
        if grabbedIndex != nil {
            try await self.moveWindowToSpace(windowIndex: grabbedIndex!, spaceIndex: targetSpaceIndex);
            try await self.focusWindow(index: grabbedIndex!);
        }
        
        if event != nil {
            CGWarpMouseCursorPosition(event!.location);
        }
        
        self.clearCache()
    }
    
    func clearCache() {
        self.displayMouseQueryCache = nil;
    }
}

enum MyError: Error {
    case runtimeError(String)
}

private let NSScreenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

extension NSScreen {
    public var identifier: String {
        guard let number = deviceDescription[NSScreenNumberKey] as? NSNumber else {
            return ""
        }

        let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}
