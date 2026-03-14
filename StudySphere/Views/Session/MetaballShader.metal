#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct MetaballNode {
    float2 position;   // in meters, relative to centroid
    float strength;    // 0.0 (fully distracted) to 1.0 (fully focused)
    float padding;
};

struct MetaballUniforms {
    float2 viewSize;        // pixels
    float radiusMeters;     // study sphere radius
    float threshold;        // isosurface threshold
    float time;             // animation time
    int nodeCount;          // active nodes
    float groupFocus;       // 0..1 average focus for color
    float centroidStrength; // stabilising blob at center
    float safeAreaTop;      // pixels from top edge
};

constant int MAX_NODES = 8;
constant int NUM_PARTICLES = 18;

// MARK: - Noise Utilities

float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash21(i + float2(0.0, 0.0));
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

float fbm(float2 p) {
    float val = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 3; i++) {
        val += amp * valueNoise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return val;
}

// MARK: - Vertex Shader

vertex VertexOut metaballVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

// MARK: - Fragment Shader
//
// All field evaluation in normalized coordinates (1.0 = radiusMeters).

fragment float4 metaballFragment(
    VertexOut in [[stage_in]],
    constant MetaballUniforms& uniforms [[buffer(0)]],
    constant MetaballNode* nodes [[buffer(1)]]
) {
    float t = uniforms.time;
    float radius = uniforms.radiusMeters;

    // UV → world-space → normalized (radius = 1.0)
    // The visualization is centered on a 1:1 square whose side = screen width,
    // starting below the safe area. aspect = width/height (< 1 in portrait).
    float aspect = uniforms.viewSize.x / uniforms.viewSize.y;
    float worldExtent = radius * 3.0;

    // Shift center down by safe area so the square aligns with the SwiftUI layout
    float safeTopUV = uniforms.safeAreaTop / uniforms.viewSize.y;
    float squareCenterY = safeTopUV + aspect * 0.5;

    float2 worldPos;
    worldPos.x = (in.uv.x - 0.5) * worldExtent;
    worldPos.y = (in.uv.y - squareCenterY) * worldExtent / aspect;

    float2 normPos = worldPos / radius;

    // --- Surface warping ---
    float2 warpOffset;
    warpOffset.x = fbm(normPos * 3.0 + float2(t * 0.24, t * 0.16)) * 0.08;
    warpOffset.y = fbm(normPos * 3.0 + float2(t * 0.20 + 5.0, t * -0.12 + 3.0)) * 0.08;
    float2 warpedNorm = normPos + warpOffset;

    // --- Scalar field in normalized space ---
    float field = 0.0;
    float focusWeightedSum = 0.0;
    float totalWeight = 0.0;
    float softness = 0.04;

    for (int i = 0; i < uniforms.nodeCount && i < MAX_NODES; i++) {
        float2 nodeNorm = nodes[i].position / radius;
        float2 diff = warpedNorm - nodeNorm;
        float distSq = max(dot(diff, diff), 0.001);

        float effectiveStrength = mix(0.15, 1.0, nodes[i].strength);

        // Per-node breathing
        float breathRate = 0.8 + float(i) * 0.15;
        float breath = 1.0 + sin(t * breathRate + float(i) * 1.47) * 0.06;
        effectiveStrength *= breath;

        float contribution = effectiveStrength / (distSq + softness);
        field += contribution;

        focusWeightedSum += nodes[i].strength * contribution;
        totalWeight += contribution;
    }

    // Centroid stabilisation
    {
        float distSq = max(dot(warpedNorm, warpedNorm), 0.001);
        float centroidBreath = 1.0 + sin(t * 0.5) * 0.04;
        float centroidContrib = (uniforms.centroidStrength * centroidBreath) / (distSq + 0.06);
        field += centroidContrib;
        focusWeightedSum += 1.0 * centroidContrib;
        totalWeight += centroidContrib;
    }

    float localFocus = (totalWeight > 0.0) ? (focusWeightedSum / totalWeight) : 1.0;

    // Soft edge transition
    float edgeSoftness = uniforms.threshold * 0.4;
    float alpha = smoothstep(uniforms.threshold - edgeSoftness,
                             uniforms.threshold + edgeSoftness * 0.5, field);

    if (alpha < 0.001) {
        discard_fragment();
    }

    // --- Coloring ---
    float3 focusedColor = float3(0.15, 0.45, 0.75);
    float3 partialColor = float3(0.45, 0.20, 0.65);
    float3 distractedColor = float3(0.75, 0.15, 0.20);

    float3 color;
    if (localFocus > 0.5) {
        float s = (localFocus - 0.5) * 2.0;
        color = mix(partialColor, focusedColor, s);
    } else {
        float s = localFocus * 2.0;
        color = mix(distractedColor, partialColor, s);
    }

    // Internal caustic flow
    float caustic1 = fbm(normPos * 4.0 + float2(t * 0.15, t * -0.10));
    float caustic2 = fbm(normPos * 3.0 + float2(t * -0.08 + 7.0, t * 0.13 + 4.0));
    float caustic = (caustic1 + caustic2) * 0.5;
    float interiorMask = smoothstep(uniforms.threshold, uniforms.threshold * 3.0, field);
    color += caustic * 0.08 * interiorMask * float3(0.4, 0.6, 1.0);

    // Inner glow
    float glowIntensity = smoothstep(uniforms.threshold, uniforms.threshold * 4.0, field);
    color = mix(color, color * 1.6, glowIntensity * 0.3);

    // Multi-layer shimmer
    float shimmer1 = sin(t * 1.5 + normPos.x * 5.0 + normPos.y * 3.5);
    float shimmer2 = sin(t * 0.7 - normPos.x * 3.5 + normPos.y * 6.0 + 2.5);
    float shimmer3 = sin(t * 2.3 + normPos.x * 2.5 - normPos.y * 5.0 + 5.0);
    float shimmer = (shimmer1 + shimmer2 * 0.6 + shimmer3 * 0.3) / 1.9;
    color *= 1.0 + shimmer * 0.04;

    // Animated edge glow with traveling waves
    float edgeDist = abs(field - uniforms.threshold) / uniforms.threshold;
    float edgeBand = 1.0 - smoothstep(0.0, 0.35, edgeDist);
    float angle = atan2(normPos.y, normPos.x);
    float edgeWave = sin(angle * 3.0 - t * 1.2) * 0.5 + 0.5;
    float edgeWave2 = sin(angle * 5.0 + t * 0.8 + 2.0) * 0.5 + 0.5;
    float combinedEdge = mix(edgeWave, edgeWave2, 0.4);
    color += edgeBand * float3(0.3, 0.5, 0.8) * (0.10 + combinedEdge * 0.12);

    // --- Drifting luminous particles inside the field ---
    float particleAccum = 0.0;
    for (int i = 0; i < NUM_PARTICLES; i++) {
        float fi = float(i);
        float seed1 = hash21(float2(fi * 1.23, fi * 0.77));
        float seed2 = hash21(float2(fi * 0.91, fi * 1.43));

        // Each particle orbits at its own speed and radius
        float orbitSpeed = 0.06 + seed1 * 0.1;
        float orbitRadius = 0.25 + seed2 * 0.45;
        float2 pPos;
        pPos.x = sin(t * orbitSpeed + fi * 2.39) * orbitRadius * (0.7 + seed1 * 0.6);
        pPos.y = cos(t * orbitSpeed * 0.7 + fi * 1.73) * orbitRadius * (0.7 + seed2 * 0.6);

        float dist = length(normPos - pPos);
        float pSize = 0.015 + seed1 * 0.025;
        float glow = smoothstep(pSize * 3.5, 0.0, dist);
        float core = smoothstep(pSize, 0.0, dist);

        // Staggered pulsing
        float pulse = sin(t * (0.8 + seed2 * 1.5) + fi * 1.1) * 0.4 + 0.6;
        particleAccum += (glow * 0.25 + core * 0.75) * pulse;
    }
    // Tint particles by focus state; only show inside the blob
    float3 particleColor = mix(float3(1.0, 0.5, 0.6), float3(0.6, 0.75, 1.0), localFocus);
    color += particleAccum * particleColor * interiorMask * 0.15;

    float finalAlpha = alpha * 0.85;
    return float4(color, finalAlpha);
}
