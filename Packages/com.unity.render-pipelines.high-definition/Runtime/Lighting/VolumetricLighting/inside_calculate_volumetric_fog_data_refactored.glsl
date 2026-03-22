// =============================================================================
// Volumetric Fog Data Generation Shader - Refactored Version
// =============================================================================
// This shader computes the volumetric fog density and packed depth texture (T1)
// that is later sampled by inside_volumetric_fog.glsl.
//
// Algorithm: Ray-march through the view frustum, accumulate fog transmittance
// using shadow map sampling for light occlusion. Outputs fog density (R) and
// 24-bit packed depth (GBA) at 1/4 resolution.
// =============================================================================

// Constant Buffers
cbuffer CB0UBO : register(b0)
{
    float4 CB0_m0[17] : packoffset(c0);
    // CB0_m0[14] - Various params:
    //             .x = fogDensityBase     (雾密度基准值)
    //             .y = mipLevel           (降采样级别, 2.0 = 1/4分辨率)
    //             .z = shadowmapScale      (阴影图缩放)
    //             .w = densityScale        (雾浓度缩放因子)
    // CB0_m0[15].w = time                  (当前时间)
    // CB0_m0[16] - Blue noise texel size: (width, height, 1/width, 1/height)
};

cbuffer CB1UBO : register(b1)
{
    float4 CB1_m0[8] : packoffset(c0);
    // CB1_m0[5].z = distanceFadeScale    (距离衰减)
    // CB1_m0[7].z = depthLinearScale     (深度线性化缩放)
    // CB1_m0[7].w = depthLinearOffset    (深度线性化偏移)
};

// Textures and Samplers
Texture2D<float4> BlueNoiseTex : register(t0);    // T0: Blue noise for dithering
Texture2D<float4> RampTex : register(t1);        // T1: 横向条 ramp 纹理 (1D光照衰减曲线)
Texture2D<float4> CircularMaskTex : register(t2); // T2: 圆形渐变 mask 纹理 (聚光灯形状遮罩)
Texture2D<float4> ShadowMapTex : register(t3);  // T3: Shadow/occlusion map (PCF sampling)
Texture2D<float4> LightDepthTex : register(t4);  // T4: 灯光起点到终点的距离纹理
                                                  //      (从光源方向看的深度，近处值大，远处值小)
Texture2D<float4> CameraDepthTex : register(t5);  // T5: 游戏相机视角的深度纹理
SamplerComparisonState ShadowSampler : register(s0); // S0: PCF shadow sampler
SamplerState LightSampler : register(s1);           // S1: CircularMask 纹理采样器
SamplerState RampSampler : register(s2);           // S2: Ramp 纹理采样器
SamplerState BlueNoiseSampler : register(s3);      // S3: Blue noise sampler

static float4 gl_FragCoord;
static float TEXCOORD;        // Ray tNear (normalized near distance)
static float4 TEXCOORD_1;    // Ray start coefficients (box min)
static float4 TEXCOORD_2;    // Ray start position
static float4 TEXCOORD_3;    // Ray end coefficients (box max)
static float4 TEXCOORD_4;    // Ray end position
static float4 SV_Target;

struct SPIRV_Cross_Input
{
    float TEXCOORD : TEXCOORD1;      // tNear
    float4 TEXCOORD_1 : TEXCOORD2;   // Box min
    float4 TEXCOORD_2 : TEXCOORD3;   // Box start
    float4 TEXCOORD_3 : TEXCOORD4;   // Box max
    float4 TEXCOORD_4 : TEXCOORD5;   // Box end
    float4 gl_FragCoord : SV_Position;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------
static const float INV_6 = 0.16666667163372039794921875f;      // 1/6 (ray march step count)
static const float INV_12 = 0.083333335816860198974609375f;    // 1/12 (half step for midpoint rule)
static const float RECIP_SQRT_MAGIC = 1597463174u;              // Magic constant for fast rsqrt
static const float SQRT_1_2 = 1.4142135623730950488016887242097f; // ?2 for normal distribution
static const uint BLUE_NOISE_PRIME_X = 1201u;
static const uint BLUE_NOISE_PRIME_Y = 1291u;
static const float DEPTH_WEIGHT_255 = 0.0039215688593685626983642578125f;  // 1/255

// Ray march step count
static const int RAY_STEPS = 6;

static bool discard_state;

// -----------------------------------------------------------------------------
// Discard Helpers
// -----------------------------------------------------------------------------
void discard_cond(bool condition)
{
    if (condition) discard_state = true;
}

void discard_exit()
{
    if (discard_state) discard;
}

// -----------------------------------------------------------------------------
// Fast Inverse Square Root (John Carmack's magic)
// Returns 1/sqrt(x) using a single Newton iteration
// -----------------------------------------------------------------------------
float FastInvSqrt(float x)
{
    // IEEE 754 float manipulation trick
    float xhalf = 0.5f * x;
    int i = asint(x);
    i = RECIP_SQRT_MAGIC - (i >> 1);
    x = asfloat(i);
    // Newton-Raphson iteration: x = x * (1.5 - xhalf * x * x)
    x = x * (1.5f - xhalf * x * x);
    return x;
}

// -----------------------------------------------------------------------------
// Fast Reciprocal Square Root
// Uses FastInvSqrt with the identity: 1/sqrt(x) = sqrt(1/x)
// But optimized: 1/sqrt(x) ? FastInvSqrt(x) for the approximation
// -----------------------------------------------------------------------------
float FastRecipSqrt(float x)
{
    float y = FastInvSqrt(x);
    // Refine with Newton iteration: y = y * (1.5 - 0.5 * x * y * y)
    // This is equivalent to: y = (3 - x * y * y) * y / 2
    float x_y_y = x * y * y;
    y = y * (1.5f - 0.5f * x_y_y);
    return y;
}

// -----------------------------------------------------------------------------
// Main Fragment Shader
// -----------------------------------------------------------------------------
void frag_main()
{
    discard_state = false;

    // ============================================================
    // 第一步：获取屏幕坐标和相机深度
    // ============================================================
    uint2 screenPos = uint2(uint(int(gl_FragCoord.x)), uint(int(gl_FragCoord.y)));
    float cameraDepthRaw = CameraDepthTex.Load(int3(screenPos, 0)).x;

    // ============================================================
    // 第二步：将灯光深度线性化
    // ============================================================
    // T4 存储灯光方向的距离（近处大，远处小），需要线性化
    // 公式：linearDepth = 1.0 / (scale * rawDepth + offset)
    float lightDepthLinear = 1.0f / mad(CB1_m0[7].z, LightDepthTex.Load(int3(screenPos, 0)).x, CB1_m0[7].w);

    // ============================================================
    // 第三步：提前剔除被遮挡的像素
    // ============================================================
    // 如果相机深度比灯光深度还远，说明相机方向上没有雾，直接丢弃
    // 这是性能优化的关键：被物体挡住的像素不需要计算雾效
    float distanceFade = CB1_m0[5].z;
    discard_cond(mad(distanceFade, cameraDepthRaw, -lightDepthLinear) < 0.0f);

    // ============================================================
    // 第四步：蓝噪声抖动
    // ============================================================
    // 用蓝噪声给采样添加微小偏移，避免时域和空域的条状噪点
    // UV 通过时间 + 屏幕坐标 + 质数混合，确保每帧采样点不同
    float2 noiseUV = float2(
        mad(CB0_m0[15].w, float(BLUE_NOISE_PRIME_X), gl_FragCoord.x) * CB0_m0[16].z,
        mad(CB0_m0[15].w, float(BLUE_NOISE_PRIME_Y), gl_FragCoord.y) * CB0_m0[16].w
    );
    float4 blueNoise = BlueNoiseTex.SampleLevel(BlueNoiseSampler, noiseUV, 0.0);
    float noiseValue = blueNoise.x;

    // ============================================================
    // 第五步：计算射线区间（射线与雾盒的交点）
    // ============================================================
    // 从顶点着色器传入的参数定义了雾盒的范围
    // TEXCOORD = 射线近端
    // TEXCOORD_1/2 = 雾盒入口的系数和位置
    // TEXCOORD_3/4 = 雾盒出口的系数和位置
    //
    // 射线区间取"灯光深度"和"雾盒边界"的较小值
    // 这样射线只穿过灯光能照到的雾的区域

    float rayStart_t = min(lightDepthLinear, TEXCOORD);
    float rayEnd_t   = min(lightDepthLinear, 1.0f / (-TEXCOORD));  // tNear → tFar

    // 计算雾盒入口和出口的位置（4个分量对应4个平面）
    float boxStart_t0 = dot(TEXCOORD_1, 1.0f / (-TEXCOORD)) + TEXCOORD_2.x;
    float boxStart_t1 = dot(TEXCOORD_1.yzwx, 1.0f / (-TEXCOORD)) + TEXCOORD_2.y;
    float boxStart_t2 = dot(TEXCOORD_1.zwxy, 1.0f / (-TEXCOORD)) + TEXCOORD_2.z;
    float boxStart_t3 = dot(TEXCOORD_1.wxyz, 1.0f / (-TEXCOORD)) + TEXCOORD_2.w;

    float boxEnd_t0 = dot(TEXCOORD_3, 1.0f / (-TEXCOORD)) + TEXCOORD_4.x;
    float boxEnd_t1 = dot(TEXCOORD_3.yzwx, 1.0f / (-TEXCOORD)) + TEXCOORD_4.y;
    float boxEnd_t2 = dot(TEXCOORD_3.zwxy, 1.0f / (-TEXCOORD)) + TEXCOORD_4.z;
    float boxEnd_t3 = dot(TEXCOORD_3.wxyz, 1.0f / (-TEXCOORD)) + TEXCOORD_4.w;
    SV_Target.xyz = boxStart_t0.xxx;
    SV_Target.w = 1;
    return;
    // 将射线分成 6 段，每段占 1/6 的长度
    float4 boxStartScaled = boxStart_t0 * INV_6;
    float4 boxStartShifted = boxStart_t1 * INV_6 + boxStart_t2;
    float4 boxStartFinal = boxStart_t3 * INV_6 + boxStartShifted;

    // 确定射线在雾中的起止范围
    float tMin = mad(rayStart_t, boxStart_t0, boxStart_t2);  // Near intersection
    float tMax = mad(rayEnd_t, boxStart_t0, boxStart_t2);    // Far intersection

    float tMin_near = mad(rayStart_t, boxStart_t1, boxStart_t3);
    float tMax_near = mad(rayEnd_t, boxStart_t1, boxStart_t3);

    float4 boxEndScaled = boxEnd_t0 * INV_6;
    float4 boxEndShifted = boxEnd_t1 * INV_6 + boxEnd_t2;
    float4 boxEndFinal = boxEnd_t3 * INV_6 + boxEndShifted;

    // ============================================================
    // 第六步：光线步进（6步，中点积分）
    // ============================================================
    // 沿射线方向分成 6 段，在每段的中点采样
    // 中点积分比均匀采样更精确（数学上的中点法则）
    //
    // 每个采样点做 3 件事：
    //   1. 查 T3 阴影图：问"这个方向有阴影吗？"
    //   2. 查 T2 圆形 mask：问"这个点在聚光灯范围内吗？"
    //   3. 查 T1 ramp 曲线：问"光传了这么远，衰减了多少？"
    // 然后把每段的"透光能力"累加起来

    float4 tMinShifted = -boxStartFinal;
    float4 tMaxShifted = -boxEndFinal;
    float4 tMinScaled = tMinShifted + boxEndFinal;
    float4 tMaxScaled = tMaxShifted + boxEndFinal;

    float4 tMinFinal = tMinScaled * INV_6 + boxStartFinal;
    float4 tMaxFinal = tMaxScaled * INV_6 + boxStartFinal;

    float tMinRatio = tMinFinal.x / tMaxFinal.x;
    float tMinRatio2 = tMinFinal.y / tMaxFinal.x;
    float tMinRatio3 = tMinFinal.z / tMaxFinal.x;

    float fogDensityBase = CB0_m0[14].x;
    float fogDensityShift = CB0_m0[14].z;
    float fogDensityBase2 = -fogDensityBase + 1.0f;
    float fogDensityBase3 = -fogDensityShift + 1.0f;

    float mipLevel = CB0_m0[14].y;
    float invMipLevel = 0.5f + mipLevel * 0.5f;  // midpoint adjustment

    // 第一个采样点（第 0 步）
    float2 shadowUV0 = float2(tMinRatio, tMinRatio2);
    float shadowDepth0 = tMinRatio3;
    float shadowSample0 = ShadowMapTex.SampleCmpLevelZero(ShadowSampler, shadowUV0, shadowDepth0).x;
    float2 lightUV0 = float2(tMinRatio + invMipLevel, tMinRatio2 + invMipLevel);
    float lightHistory0 = CircularMaskTex.SampleLevel(LightSampler, lightUV0, mipLevel).w;
    float fogDensity0 = shadowSample0 * fogDensityBase3 + fogDensityBase3;
    float3 samplePos0 = float3(tMinFinal.x, tMinFinal.y, tMinFinal.z);
    float sampleLength0 = dot(samplePos0, samplePos0);
    float historySample0 = RampTex.SampleLevel(RampSampler, float2(sampleLength0, 0.5f), 0.0f).x;
    float transmittance = fogDensity0 * (fogDensityBase2 + historySample0 * fogDensityBase) * lightHistory0;

    // 后续采样点（步进 1-5）
    float t0 = tMinFinal.x;
    float t1 = tMinFinal.y;
    float t2 = tMinFinal.z;
    float t3 = tMinFinal.w;
    float t4 = tMaxFinal.x;
    float t5 = tMaxFinal.y;
    float t6 = tMaxFinal.z;
    float t7 = tMaxFinal.w;

    
    SV_Target.xyz = lightHistory0.xxx;
    SV_Target.w = 1;
    return;

    for (uint step = 1u; step < uint(RAY_STEPS); step++)
    {
        // 计算每段的中点位置（每对占 2/12 = 1/6）
        float t0_next = mad(boxEndShifted.x, INV_6, t0);
        float t1_next = mad(boxEndShifted.y, INV_6, t1);
        float t2_next = mad(boxEndShifted.z, INV_6, t2);
        float t3_next = mad(boxEndShifted.w, INV_6, t3);
        float t0_curr = mad(boxStartShifted.x, INV_6, t0);
        float t1_curr = mad(boxStartShifted.y, INV_6, t1);
        float t2_curr = mad(boxStartShifted.z, INV_6, t2);
        float t3_curr = mad(boxStartShifted.w, INV_6, t3);

        float tRatio = t0_curr / t3_curr;
        float tRatio2 = t1_curr / t3_curr;
        float tRatio3 = t2_curr / t3_curr;

        float2 shadowUV = float2(tRatio, tRatio2);
        float shadowDepth = tRatio3;
        float shadowSample = ShadowMapTex.SampleCmpLevelZero(ShadowSampler, shadowUV, shadowDepth).x;

        float2 lightUV = float2(tRatio + invMipLevel, tRatio2 + invMipLevel);
        float lightHistory = CircularMaskTex.SampleLevel(LightSampler, lightUV, mipLevel).w;

        float fogDensity = shadowSample * fogDensityBase3 + fogDensityBase3;

        float3 samplePos = float3(t0_curr, t1_curr, t2_curr);
        float sampleLength = dot(samplePos, samplePos);
        float historySample = RampTex.SampleLevel(RampSampler, float2(sampleLength, 0.5f), 0.0f).x;

        float stepTransmittance = fogDensity * (fogDensityBase2 + historySample * fogDensityBase) * lightHistory;

        // 用中点法则累加透射率
        transmittance = mad(stepTransmittance, mad(fogDensityBase, historySample, fogDensityBase2), transmittance);

        // 移动到下一段
        t0 = t0_next;
        t1 = t1_next;
        t2 = t2_next;
        t3 = t3_next;
    }

    // ============================================================
    // 第七步：计算最终透射率 + 法线分布校正
    // ============================================================
    // 透射率 = 累加值 × 射线长度 × 密度缩放
    float tDelta = tMax - tMin;
    float densityScale = CB0_m0[14].w;
    float adjustedTransmittance = transmittance * tDelta * densityScale;


    // 用快速反平方根做法线分布校正，让雾的浓淡更平滑自然
    float normFactor = FastRecipSqrt(adjustedTransmittance);
    float normalDist = mad(normFactor, -adjustedTransmittance, 1.5f) * normFactor;

    // ============================================================
    // 第八步：将相机深度打包成 24 位
    // ============================================================
    // 深度值拆成 3 个字节存入 GBA 通道
    // 解码公式：depth = y + z/255 + w/65535

    float depthClamped = min(max(cameraDepthRaw, 0.0f), 0.99999988079071044921875f);

    float scaled1 = depthClamped;
    float scaled255 = depthClamped * 255.0f;
    float scaled65025 = depthClamped * 65025.0f;

    float frac255 = frac(scaled255);
    float frac65025 = frac(scaled65025);

    // G通道：frac(depth) - frac(depth×255)/255
    SV_Target.y = mad(-frac255, DEPTH_WEIGHT_255, frac(scaled1));
    // B通道：frac(depth×255) - frac(depth×65025)/255
    SV_Target.z = mad(-frac65025, DEPTH_WEIGHT_255, frac255);
    // A通道：frac(depth×65025) - frac(depth×65025)/255
    SV_Target.w = mad(-frac65025, DEPTH_WEIGHT_255, frac65025);

    // ============================================================
    // 第九步：计算雾密度写入 R 通道
    // ============================================================
    // 最终雾密度 = 校正后的透射率 + 蓝噪声偏移
    // 蓝噪声偏移用于减少量化误差
    float depthBias = (blueNoise.z + blueNoise.y - 1.5f) * DEPTH_WEIGHT_255;
    SV_Target.x = mad(adjustedTransmittance, normalDist, depthBias);

    discard_exit();
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    gl_FragCoord = stage_input.gl_FragCoord;
    gl_FragCoord.w = 1.0f / gl_FragCoord.w;
    TEXCOORD = stage_input.TEXCOORD;
    TEXCOORD_1 = stage_input.TEXCOORD_1;
    TEXCOORD_2 = stage_input.TEXCOORD_2;
    TEXCOORD_3 = stage_input.TEXCOORD_3;
    TEXCOORD_4 = stage_input.TEXCOORD_4;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}
