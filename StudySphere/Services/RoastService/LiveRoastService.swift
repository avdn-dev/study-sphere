import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

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
            .disabled(isGenerating)
            
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
    
    var isBrainRot: Bool = false
    var isBotReady: Bool = false
    
    // Stored as Any? to ensure it compiles safely on deployment targets below iOS 26
    private var internalSession: Any?
    
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
        setupModel()
    }
    
    private func setupModel() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.isAvailable {
                self.internalSession = LanguageModelSession(instructions: LiveRoastService.systemPrompt)
                self.isBotReady = true
            } else {
                print("Apple Intelligence is not available on this device.")
            }
        }
        #endif
    }
    
    public func generateRoasts(roastType: RoastType) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 16.0, *) {
            guard let session = internalSession as? LanguageModelSession else {
                return []
            }
            
            let style = isBrainRot ? "Use gen-z internet slang and brain rot terminology." : "Use standard English."
            let promptText = "Generate 3 \(roastType.description) roasts about my coding skills. \(style)"
            
            do {
                let response = try await session.respond(to: promptText)
                print("RAW ANSWER:", response.content)
                
                return response.content.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            } catch {
                print("Generation error:", error)
                return []
            }
        }
        #endif
        
        return getHardcodedRoasts(roastType: roastType, isBrainRot: isBrainRot)
    }
    
    private func getHardcodedRoasts(roastType: RoastType, isBrainRot: Bool) -> [String] {
            if isBrainRot {
                switch roastType {
                case .raw, .rare:
                    return [
                        "bro is not locked in.",
                        "scrolling gives negative aura.",
                        "why are we opening this app?",
                        "your focus is mid.",
                        "bro is trying to doomscroll."
                    ]
                case .mediumRare, .medium:
                    return [
                        "get off the app and lock in.",
                        "you have zero rizz and zero focus.",
                        "this is certified brain rot behavior.",
                        "who let bro slack off?",
                        "your screen time is looking tragic."
                    ]
                case .done, .wellDone, .cooked:
                    return [
                        "get back to work bum.",
                        "you are completely cooked if you keep scrolling.",
                        "bro is a certified npc for dodging work.",
                        "pack it up and do your actual job.",
                        "delete the app and touch grass."
                    ]
                }
            } else {
                switch roastType {
                case .raw, .rare:
                    return [
                        "you should be working.",
                        "close the app.",
                        "this is not what you need to do right now.",
                        "focus on your tasks.",
                        "you are getting distracted."
                    ]
                case .mediumRare, .medium:
                    return [
                        "stop wasting time.",
                        "you have actual work to finish.",
                        "why are you opening this.",
                        "procrastination won't help you.",
                        "get back to your responsibilities."
                    ]
                case .done, .wellDone, .cooked:
                    return [
                        "get back to work bum.",
                        "you are throwing your day away.",
                        "stop being lazy and do something productive.",
                        "this app is blocked for a reason.",
                        "staring at a screen won't finish your work."
                    ]
                }
            }
        }
}
