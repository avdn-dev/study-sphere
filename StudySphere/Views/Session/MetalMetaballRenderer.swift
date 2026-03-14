import MetalKit

final class MetalMetaballRenderer: NSObject, MTKViewDelegate {

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let pipelineState: any MTLRenderPipelineState
    private var uniformBuffer: any MTLBuffer
    private var nodeBuffer: any MTLBuffer

    private let maxNodes = 8
    private var nodes: [MetaballNodeBridge] = []
    private var groupFocus: Float = 1.0
    private var radiusMeters: Float = 5.0
    private let startTime = CFAbsoluteTimeGetCurrent()

    // MARK: - Init

    init?(mtkView: MTKView) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }

        self.device = device
        self.commandQueue = queue
        mtkView.device = device

        // Load shaders
        guard let library = device.makeDefaultLibrary(),
              let vertexFn = library.makeFunction(name: "metaballVertex"),
              let fragmentFn = library.makeFunction(name: "metaballFragment") else { return nil }

        // Pipeline
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

        // Alpha blending for transparent background
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.pipelineState = pipeline

        // Buffers — storageModeShared for CPU+GPU access
        guard let uBuf = device.makeBuffer(
            length: MemoryLayout<MetaballUniformsBridge>.stride,
            options: .storageModeShared),
              let nBuf = device.makeBuffer(
                length: MemoryLayout<MetaballNodeBridge>.stride * maxNodes,
                options: .storageModeShared) else { return nil }

        self.uniformBuffer = uBuf
        self.nodeBuffer = nBuf

        super.init()

        #if DEBUG
        MetaballBridgeLayoutAssertions.verify()
        #endif
    }

    // MARK: - Public API

    func updateNodes(_ newNodes: [MetaballNodeBridge], groupFocus: Float, radiusMeters: Float) {
        self.nodes = Array(newNodes.prefix(maxNodes))
        self.groupFocus = groupFocus
        self.radiusMeters = radiusMeters
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor else { return }

        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        passDescriptor.colorAttachments[0].loadAction = .clear

        let time = Float(CFAbsoluteTimeGetCurrent() - startTime)
        let size = view.drawableSize

        // Convert safe area from points to pixels
        let scale = size.height / view.bounds.height
        let safeTopPx = Float(view.safeAreaInsets.top * scale)

        // Build uniforms
        var uniforms = MetaballUniformsBridge(
            viewSize: SIMD2<Float>(Float(size.width), Float(size.height)),
            radiusMeters: radiusMeters,
            threshold: 5.5,
            time: time,
            nodeCount: Int32(nodes.count),
            groupFocus: groupFocus,
            centroidStrength: 0.6,
            safeAreaTop: safeTopPx
        )

        // Copy to GPU buffers
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<MetaballUniformsBridge>.stride)

        if !nodes.isEmpty {
            nodes.withUnsafeBufferPointer { ptr in
                memcpy(nodeBuffer.contents(), ptr.baseAddress!, ptr.count * MemoryLayout<MetaballNodeBridge>.stride)
            }
        }

        // Encode draw call
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(nodeBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
