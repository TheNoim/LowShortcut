////
////  handler.swift
////  LowShortcut
////
////  Created by Nils Bergmann on 13/06/2022.
////
//
import Foundation

class YabaiCommandHandler {
    var running = false;
    var lock = NSLock();
    let yabai: Yabai;
    
    init(yabai: Yabai) {
        self.yabai = yabai
    }
    
    enum YabaiCommand {
        case Next
        case Back
        case NextSpaceAndMoveWindow
        case BackSpaceAndMoveWindow
    }
    
    var nextCommand: YabaiCommand?;
    
    func addNextCommand(command: YabaiCommand) async throws {
        self.lock.lock();
        if running {
            nextCommand = command;
            self.lock.unlock();
        } else {
            try await self.runNextCommand(command: command);
        }
    }
    
    private func runNextCommand(command: YabaiCommand) async throws {
        running = true;
        async let nextTask: Void = self.execNextCommand(command: command);
        self.lock.unlock();
        try await nextTask;
        self.lock.lock();
        if let nextCommand = self.nextCommand {
            self.running = true;
            async let nextNextTask: Void = self.runNextCommand(command: nextCommand)
            self.nextCommand = nil;
            self.lock.unlock();
            try await nextNextTask;
        } else {
            self.running = false;
            self.lock.unlock();
        }
    }

    private func execNextCommand(command: YabaiCommand) async throws -> Void {
        do {
            switch (command) {
            case .Back:
                try await self.yabai.back();
                break;
            case .Next:
                try await self.yabai.next();
                break;
            case .NextSpaceAndMoveWindow:
                try await self.yabai.next(moveWindow: true);
                break;
            case .BackSpaceAndMoveWindow:
                try await self.yabai.back(moveWindow: true);
                break;
            }
        } catch {
            await self.yabai.clearCache();
            throw error;
        }
        return;
    }
}
