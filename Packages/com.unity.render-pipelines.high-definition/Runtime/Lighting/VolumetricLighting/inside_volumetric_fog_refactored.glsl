// =============================================================================
// Volumetric Fog Shader - Refactored/Restored Version
// =============================================================================
// This is a cleaned up version of the decompiled SPIRV shader.
// The algorithm has been restored for readability while preserving
// the exact same computation results.
// =============================================================================

// Constant Buffers
cbuffer CB0UBO : register(b0)
{
    float4 CB0_m0[15] : packoffset(c0);
    // CB0_m0[12] - Fog color (RGB)
    // CB0_m0[13] - Time related: (time_scale, time_scale_ms, ?, time)
    // CB0_m0[14] - Blue noise texture size (width, height, 1/width, 1/height)
};

cbuffer CB1UBO : register(b1)
{
    float4 CB1_m0[8] : packoffset(c0);
    // CB1_m0[7] - Depth unprojection params (x: linear scale, y: linear offset)
};

// Textures and Samplers
Texture2D<float4> BlueNoiseTex : register(t0);  // Blue noise texture for dithering
Texture2D<float4> T1 : register(t1);            // Volumetric fog texture (depth in .yzw)
Texture2D<float4> DepthTex : register(t2);            // Scene depth texture
SamplerState S0 : register(s0);

static float4 gl_FragCoord;
static float4 SV_Target;

struct SPIRV_Cross_Input
{
    float4 gl_FragCoord : SV_Position;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------
static const float PI = 3.14159265358979323846;          // 6.283185482025146484375 / 2
static const float TWO_PI = 6.283185482025146484375;
static const float SAMPLE_RADIUS = 3.099999904632568359375;  // Sampling radius in pixels
static const float DEPTH_WEIGHT = 1.0;
static const float DEPTH_WEIGHT_255 = 0.0039215688593685626983642578125;  // 1/255
static const float DEPTH_WEIGHT_65535 = 1.5378700481960549950599670410156e-05;  // 1/65535
static const float EPSILON = 9.9999997473787516355514526367188e-06;
static const uint FLOAT_MAGIC = 532487669u;  // Magic number for fast random float generation

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

// Reconstruct linear depth from packed YZW components
// The depth is packed as: depth = y * 1.0 + z * (1/255) + w * (1/65535)
float UnpackDepth(float3 packedDepth)
{
    return dot(packedDepth, float3(DEPTH_WEIGHT, DEPTH_WEIGHT_255, DEPTH_WEIGHT_65535));
}

// Fast random float generation using IEEE 754 float manipulation
// This creates a pseudo-random value from the blue noise channel
float FastRandomFloat(float input)
{
    // This is a clever trick: interpret float as uint, shift right by 1,
    // add a magic number, and interpret back as float
    // This produces a value roughly in [0, 1] range with good distribution
    uint inputAsUint = asuint(input);
    uint shifted = inputAsUint >> 1u;
    uint withMagic = shifted + FLOAT_MAGIC;
    return asfloat(withMagic);
}

// Generate a sample offset position using blue noise
float2 GenerateSampleOffset(float blueNoiseChannel, float angleOffset)
{
    // Use blue noise to generate a random angle
    float angle = blueNoiseChannel * TWO_PI;

    // Calculate offset direction (unit circle)
    float2 direction = float2(cos(angle), sin(angle));

    // Scale by sample radius
    return direction * SAMPLE_RADIUS;
}

// Sample the volumetric fog texture at an offset position
void SampleFogAtOffset(float2 centerPos, float2 offset, out float fogValue, out float linearDepth)
{
    // Calculate sample position (half resolution, hence * 0.5)
    int2 samplePos = int2(uint2(
        uint(int(centerPos.x * 0.5 + offset.x)),
        uint(int(centerPos.y * 0.5 + offset.y))
    ));

    float4 sampleData = T1.Load(int3(samplePos, 0));
    fogValue = sampleData.x;
    linearDepth = UnpackDepth(sampleData.yzw);
}

// -----------------------------------------------------------------------------
// Main Fragment Shader
// -----------------------------------------------------------------------------
void frag_main()
{
    // --- Step 1: Blue Noise Sampling ---
    // Use time-varying UV to animate the blue noise pattern
    float timeValue = CB0_m0[13].w;  // Current time
    float2 noiseUV = float2(
        mad(timeValue, 1259.0, gl_FragCoord.x) * CB0_m0[14].z,  // 1259 is a prime for better distribution
        mad(timeValue, 1277.0, gl_FragCoord.y) * CB0_m0[14].w   // 1277 is another prime
    );

    float4 blueNoise = BlueNoiseTex.SampleLevel(S0, noiseUV, 0.0);

    // blueNoise = 0;
    float blueNoiseY = blueNoise.y;

    // DEBUG: Output blue noise only (matching original debug output)
    // SV_Target.xyz = blueNoiseY.xxx;
    // SV_Target.w = 1;
    // return;

    // --- Step 2: Generate 4 Spatial Sample Offsets ---
    // Using 4 different blue noise channels/offsets for stochastic sampling
    // This creates a temporal-spatial jittering pattern

    // Sample 0: Use blueNoise.y with 0.0 offset
    float random0 = FastRandomFloat(blueNoiseY * 0.25);
    float2 offset0 = GenerateSampleOffset(blueNoise.x, 0.0);

    // Sample 1: Use blueNoise.y with 0.25 offset
    float random1 = FastRandomFloat(mad(blueNoiseY, 0.25, 0.25));
    float2 offset1 = float2(-offset0.y, offset0.x);  // Rotated 90 degrees

    // Sample 2: Use blueNoise.y with 0.5 offset
    float random2 = FastRandomFloat(mad(blueNoiseY, 0.25, 0.5));
    float2 offset2 = float2(-offset0.x, -offset0.y);  // Rotated 180 degrees

    // Sample 3: Use blueNoise.y with 0.75 offset
    float random3 = FastRandomFloat(mad(blueNoiseY, 0.25, 0.75));
    float2 offset3 = float2(offset0.y, -offset0.x);  // Rotated 270 degrees

    // Apply random scaling to each offset
    offset0 = offset0 * random0;
    offset1 = offset1 * random1;
    offset2 = offset2 * random2;
    offset3 = offset3 * random3;

    // --- Step 3: Sample Volumetric Fog at 4 Positions ---
    float fog0, fog1, fog2, fog3;
    float depth0, depth1, depth2, depth3;

    SampleFogAtOffset(gl_FragCoord.xy, offset0, fog0, depth0);
    SampleFogAtOffset(gl_FragCoord.xy, offset1, fog1, depth1);
    SampleFogAtOffset(gl_FragCoord.xy, offset2, fog2, depth2);
    SampleFogAtOffset(gl_FragCoord.xy, offset3, fog3, depth3);

    // --- Step 4: Depth-Based Edge Detection ---
    // Calculate depth range to detect edges/discontinuities
    float minDepth = min(min(min(depth3, depth2), depth1), depth0);
    float maxDepth = max(max(max(depth3, depth2), depth1), depth0);
    float depthRange = maxDepth - minDepth;
    float avgDepth = (depth0 + depth1 + depth2 + depth3) * 0.25;

    // Normalize depth range by average depth to get contrast measure
    float depthContrast = depthRange / avgDepth;

    // --- Step 5: Adaptive Filtering Based on Depth Contrast ---
    float fogResult;

    if (depthContrast < 0.1)
    {
        // Low contrast area: use simple average (faster, less noise)
        fogResult = (fog0 * fog0 + fog1 * fog1 + fog2 * fog2 + fog3 * fog3) * 0.25;
    }
    else
    {
        // High contrast area (edge): use depth-weighted average
        // This reduces ghosting artifacts at depth discontinuities

        // Get scene depth from depth buffer
        float sceneDepthSample = DepthTex.Load(int3(uint2(uint(gl_FragCoord.x), uint(gl_FragCoord.y)), 0)).x;

        // Linearize scene depth
        float linearSceneDepth = 1.0 / mad(CB1_m0[7].x, sceneDepthSample, CB1_m0[7].y);

        // Calculate weight for each sample based on depth difference from scene
        float diff0 = abs(linearSceneDepth - depth0) + EPSILON;
        float diff1 = abs(linearSceneDepth - depth1) + EPSILON;
        float diff2 = abs(linearSceneDepth - depth2) + EPSILON;
        float diff3 = abs(linearSceneDepth - depth3) + EPSILON;

        // Inverse weighting: closer samples get higher weight
        float weight0 = 1.0 / diff0;
        float weight1 = 1.0 / diff1;
        float weight2 = 1.0 / diff2;
        float weight3 = 1.0 / diff3;

        float totalWeight = weight0 + weight1 + weight2 + weight3;

        // Weighted average of squared fog values
        fogResult = dot(float4(weight0, weight1, weight2, weight3),
                       float4(fog0 * fog0, fog1 * fog1, fog2 * fog2, fog3 * fog3)) / totalWeight;
    }

    // --- Step 6: Final Color Composition ---
    // Use blue noise channels for temporal dithering
    float ditherR = blueNoiseY * DEPTH_WEIGHT_255;
    float ditherG = blueNoise.z * DEPTH_WEIGHT_255;
    float ditherB = blueNoise.w * DEPTH_WEIGHT_255;

    ditherR = 0;
    ditherG = 0;
    ditherB = 0;

    // Combine fog result with fog color and dithering
    float3 fogColor = CB0_m0[12].rgb;  // Fog color from constant buffer

    SV_Target.x = mad(fogResult, fogColor.r, -ditherR);
    SV_Target.y = mad(fogResult, fogColor.g, -ditherG);
    SV_Target.z = mad(fogResult, fogColor.b, -ditherB);
    SV_Target.w = 1.0;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    gl_FragCoord = stage_input.gl_FragCoord;
    gl_FragCoord.w = 1.0 / gl_FragCoord.w;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}
