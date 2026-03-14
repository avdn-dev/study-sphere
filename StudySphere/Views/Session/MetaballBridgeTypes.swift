import simd

/// Mirrors `MetaballNode` in MetaballShader.metal — 16 bytes, tightly packed.
struct MetaballNodeBridge {
    var position: SIMD2<Float>   // 8 bytes — world-space meters
    var strength: Float          // 4 bytes — 0 (distracted) … 1 (focused)
    var padding: Float = 0       // 4 bytes — alignment padding
}

/// Mirrors `MetaballUniforms` in MetaballShader.metal — 36 bytes.
struct MetaballUniformsBridge {
    var viewSize: SIMD2<Float>        // 8 bytes
    var radiusMeters: Float           // 4 bytes
    var threshold: Float              // 4 bytes
    var time: Float                   // 4 bytes
    var nodeCount: Int32              // 4 bytes
    var groupFocus: Float             // 4 bytes
    var centroidStrength: Float       // 4 bytes
    var safeAreaTop: Float            // 4 bytes — pixels from top edge
}

#if DEBUG
enum MetaballBridgeLayoutAssertions {
    static func verify() {
        assert(MemoryLayout<MetaballNodeBridge>.size == 16,
               "MetaballNodeBridge must be 16 bytes to match Metal struct")
        assert(MemoryLayout<MetaballUniformsBridge>.size == 36,
               "MetaballUniformsBridge must be 36 bytes to match Metal struct")
    }
}
#endif
