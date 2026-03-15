//
//  LiveRoastService.swift
//  StudySphere
//
//  Created by Chris Wong on 14/3/2026.
//

import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon

struct TestView: View {
    @State var roastService = LiveRoastService()
    @State var generatedRoasts: [String] = []
    @State var isGenerating = false
    
    var body: some View {
        VStack {
            Button(isGenerating ? "ROASTING..." : "ROASTS") {
                Task {
                    isGenerating = true
                    roastService.isBrainRot = true
                    generatedRoasts = await roastService.generateRoasts(roastType: .cooked)
                    isGenerating = false
                }
            }
            .disabled(!roastService.isBotReady || isGenerating)
            
            if isGenerating {
                ProgressView()
                    .padding()
            }
            
            List(generatedRoasts, id: \.self) { roast in
                Text(roast)
            }
        }
    }
}

@Observable
final class LiveRoastService {
    static let appGroupID = "group.studio.cgc.StudySphere.sharedData"
    static let roastsKey = "shield.roasts"

    static let systemPrompt = """
        You are a toxic roasting assistant.
        Generate short, harsh roasts.
        You must separate each roast with the newline character.
        Do not write any other text, introductions, or explanations.
        Only output the roasts separated by a newline.
        """
    //    private var bot: LLM?

    var isBrainRot: Bool = false
    var isBotReady: Bool = false
    var isPerformant: Bool = false
    var session: ChatSession?
    
    enum RoastType: Float {
        case raw, rare, mediumRare, medium, done, wellDone, cooked
        
        var description: String {
            switch self {
            case .raw: return "mild and slightly annoying"
            case .rare: return "passive aggressive"
            case .mediumRare: return "snarky"
            case .medium: return "mean and direct"
            case .done: return "harsh and insulting"
            case .wellDone: return "absolutely brutal"
            case .cooked: return "soul-crushing"
            }
        }
    }
    
    public init() {
//        let canUseModel = ProcessInfo.processInfo.isDeviceCertified(for: .iPhonePerformanceGaming)
//        print("canUseModel: \(canUseModel)")
//        if canUseModel {
//            Task {
//                do {
//                    MLX.Memory.cacheLimit = 1
//                    let model = try await loadModel(id: "mlx-community/Qwen3-4B-4bit")
//                    self.session = ChatSession(model)
//                    self.isBotReady = true
//                } catch {
//                    print("ERROR LOADING LLM ", error)
//                }
//            }
//        }
//        self.isPerformant = canUseModel
    }
    
    public func generateRoasts(roastType: RoastType) async -> [String] {
        if self.isPerformant {
            await _generateRoastsUsingModel(roastType: roastType)
        } else {
            await _getPreMadeRoast(roastType: roastType)
        }
    }
    
    private func _generateRoastsUsingModel(roastType: RoastType) async -> [String] {
        precondition(self.isPerformant)
        guard let session = session else {
            return []
        }
        
        defer {
            self.session = nil
            MLX.Memory.clearCache()
        }
        
        let style = isBrainRot ? "Use gen-z internet slang and brain rot terminology." : "Use standard English."
        let promptText = "\(Self.systemPrompt) Generate 3 \(roastType.description) roasts about my coding skills. Put each roast on a separate line."
        
        do {
            let answer = try await session.respond(to: promptText)
            print("RAW ANSWER:", answer)
            
            let lines = answer.split(separator: "\n")
            let thinkEndIndex = lines.firstIndex { $0.contains("</think>") }
            let roastLines = lines[(thinkEndIndex ?? 0 + 1)...]
            return roastLines.map {
                String($0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .punctuationCharacters)
                    .drop { $0 == "|" })
            }
            await session.clear()
        } catch {
            print(error)
            await session.clear()
            return []
        }
    }
    
    /// Generate roasts and persist them to the shared app group so the
    /// ShieldConfigurationExtension can display them on blocked-app screens.
    func generateAndPersistRoasts(roastType: RoastType) async {
        let roasts = await generateRoasts(roastType: roastType)
        guard !roasts.isEmpty else { return }
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        defaults?.set(roasts, forKey: Self.roastsKey)
    }

    private func _getPreMadeRoast(roastType: RoastType) async -> [String] {
        assert(!self.isPerformant, "Prefer to use the LLM-based generation function instead if device is capable.")
        switch roastType {
        case .raw:
            return []
        case .rare:
            return []
        case .mediumRare:
            return []
        case .medium:
            return []
        case .done:
            return []
        case .wellDone:
            return []
        case .cooked:
            return []
        }
    }
}
