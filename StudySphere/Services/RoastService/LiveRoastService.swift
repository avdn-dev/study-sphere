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
    static let systemPrompt = "You are a toxic roasting assistant. Generate short, harsh roasts. You must separate each roast with the '|' character. Do not write any other text, introductions, or explanations. Only output the roasts separated by '|'."
    //    private var bot: LLM?
    
    var isBrainRot: Bool = false
    var isBotReady: Bool = false
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
        Task {
            do {
                let model = try await loadModel(id: "mlx-community/Qwen3-4B-4bit")
                self.session = ChatSession(model)
                self.isBotReady = true
            } catch {
                print("ERROR LOADING LLM ", error)
            }
        }
    }
    
    public func generateRoasts(roastType: RoastType) async -> [String] {
        guard let session = session else {
            return []
        }
        
        let style = isBrainRot ? "Use gen-z internet slang and brain rot terminology." : "Use standard English."
        let promptText = "\(Self.systemPrompt) Generate 3 \(roastType.description) roasts about my coding skills. \(style)"
        
        do {
            let answer = try await session.respond(to: promptText)
            print("RAW ANSWER:", answer)
            
            return answer.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            print(error)
            return []
        }
    }
}
