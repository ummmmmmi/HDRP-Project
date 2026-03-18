# VolumetricLightingPass Blue Noise 阴影采样降噪方案

## 目录
- [当前架构分析](#当前架构分析)
- [方案一：Blue Noise Jittered Shadow Sampling（推荐）](#方案一blue-noise-jittered-shadow-sampling推荐)
- [方案二：Multi-sample Blue Noise Shadow](#方案二multi-sample-blue-noise-shadow更高质量但性能开销更大)
- [方案三：利用现有的 BND Sequence（最佳方案）](#方案三利用现有的-bnd-sequence最佳方案)
- [C# 端修改](#c-端修改)
- [工作原理](#工作原理)
- [性能考虑](#性能考虑)

---

## 当前架构分析

### 相关文件路径
- **VolumetricLighting Compute Shader**: `Runtime/Lighting/VolumetricLighting/VolumetricLighting.compute`
- **VolumetricLighting C#**: `Runtime/Lighting/VolumetricLighting/HDRenderPipeline.VolumetricLighting.cs`
- **BlueNoise Utility**: `Runtime/RenderPipeline/Utility/BlueNoise.cs`
- **Shadow Sampling**: `Runtime/Lighting/Shadow/HDShadowSampling.hlsl`
- **Shadow Algorithms**: `Runtime/Lighting/Shadow/HDShadowAlgorithms.hlsl`
- **Raytracing Sampling (BND)**: `Runtime/RenderPipeline/Raytracing/Shaders/RaytracingSampling.hlsl`

### 关键代码位置

#### VolumetricLighting.compute 中的阴影采样 (第 198-200 行)
```hlsl
context.shadowValue = GetDirectionalShadowAttenuation(context.shadowContext,
                                                      posInput.positionSS, posInput.positionWS, shadowN,
                                                      light.shadowIndex, L);
```

#### 当前使用的阴影质量设置 (第 35 行)
```hlsl
#define DIRECTIONAL_SHADOW_ULTRA_LOW  // Different options are too expensive.
```

#### ULTRA_LOW 对应的采样算法 (HDShadowAlgorithms.hlsl 第 41 行)
```hlsl
#define DIRECTIONAL_FILTER_ALGORITHM(sd, posSS, posTC, tex, samp, bias) SampleShadow_Gather_PCF(_CascadeShadowAtlasSize.zwxy, posTC, tex, samp, bias)
```

#### 现有的 Blue Noise 资源 (BlueNoise.cs)
```csharp
public Texture2D[] textures16L { get; }      // 单通道 16x16 纹理
public Texture2D[] textures16RGB { get; }    // 多通道 16x16 纹理
public Texture2DArray textureArray16L { get; }
public Texture2DArray textureArray16RGB { get; }
```

#### 现有的 BND Sequence 函数 (RaytracingSampling.hlsl 第 57-77 行)
```hlsl
float GetBNDSequenceSample(uint2 pixelCoord, uint sampleIndex, uint sampleDimension)
{
    // wrap arguments
    pixelCoord = pixelCoord & 127;
    sampleIndex = sampleIndex & 255;
    sampleDimension = sampleDimension & 255;

    // xor index based on optimized ranking
    uint rankingIndex = (pixelCoord.x + pixelCoord.y * 128) * 8 + (sampleDimension & 7);
    uint rankedSampleIndex = sampleIndex ^ clamp((uint)(_RankingTileXSPP[uint2(rankingIndex & 127, rankingIndex / 128)] * 256.0), 0, 255);

    // fetch value in sequence
    uint value = clamp((uint)(_OwenScrambledTexture[uint2(sampleDimension, rankedSampleIndex.x)] * 256.0), 0, 255);

    // If the dimension is optimized, xor sequence value based on optimized scrambling
    uint scramblingIndex = (pixelCoord.x + pixelCoord.y * 128) * 8 + (sampleDimension & 7);
    float scramblingValue = min(_ScramblingTileXSPP[uint2(scramblingIndex & 127, scramblingIndex / 128)], 0.999);
    value = value ^ uint(scramblingValue * 256.0);

    // Convert to float
    return (scramblingValue + value) / 256.0;
}
```

---

## 方案一：Blue Noise Jittered Shadow Sampling（推荐）

这个方案利用 Blue Noise 对阴影采样位置进行偏移，通过时域累积达到降噪效果。

### 1. 修改 VolumetricLighting.compute - 添加 Blue Noise 采样函数

在文件头部的 **Inputs & outputs** 部分（约第 78 行之后）添加：

```hlsl
//--------------------------------------------------------------------------------------------------
// Blue Noise Resources
//--------------------------------------------------------------------------------------------------
TEXTURE2D(_BlueNoiseTexture);
SAMPLER(s_linear_repeat_sampler);

// 添加 Blue Noise 采样函数
float SampleBlueNoise(uint2 pixelCoord, float frameIndex)
{
    // 使用 128x128 的 blue noise texture
    uint2 noiseCoord = pixelCoord & 127;
    float noise = SAMPLE_TEXTURE2D_LOD(_BlueNoiseTexture, s_linear_repeat_sampler,
                                       float2(noiseCoord) / 128.0 + float2(frameIndex * 0.618, 0), 0).r;
    return noise;
}

// 生成 2D Blue Noise 偏移
float2 SampleBlueNoise2D(uint2 pixelCoord, float frameIndex)
{
    uint2 noiseCoord = pixelCoord & 127;
    float2 uv = float2(noiseCoord) / 128.0;

    // 使用不同的偏移获取两个独立的 blue noise 值
    float noiseX = SAMPLE_TEXTURE2D_LOD(_BlueNoiseTexture, s_linear_repeat_sampler,
                                        uv + float2(frameIndex * 0.618, 0), 0).r;
    float noiseY = SAMPLE_TEXTURE2D_LOD(_BlueNoiseTexture, s_linear_repeat_sampler,
                                        uv + float2(0, frameIndex * 0.618 + 0.5), 0).r;
    return float2(noiseX, noiseY);
}
```

### 2. 修改阴影采样 - 在 EvaluateVoxelLightingDirectional 函数中

找到 `EvaluateVoxelLightingDirectional` 函数（约第 157 行），在阴影采样部分修改：

**原代码（第 198-200 行）：**
```hlsl
context.shadowValue = GetDirectionalShadowAttenuation(context.shadowContext,
                                                      posInput.positionSS, posInput.positionWS, shadowN,
                                                      light.shadowIndex, L);
```

**修改为：**
```hlsl
// 使用 Blue Noise 生成阴影采样偏移
float2 blueNoiseOffset = SampleBlueNoise2D(posInput.positionSS, _VBufferSampleOffset.z);
float2 shadowJitter = (blueNoiseOffset * 2.0 - 1.0) * _VolumetricShadowJitterScale;

// 应用 Blue Noise 偏移到阴影采样
context.shadowValue = GetDirectionalShadowAttenuationWithJitter(
    context.shadowContext,
    posInput.positionSS,
    posInput.positionWS,
    shadowN,
    light.shadowIndex,
    L,
    shadowJitter
);
```

### 3. 添加带抖动的阴影采样函数

在 `HDShadowSampling.hlsl` 或直接在 `VolumetricLighting.compute` 中添加：

```hlsl
// 带空间抖动的方向光阴影采样
real GetDirectionalShadowAttenuationWithJitter(
    ShadowContext shadowContext,
    uint2 positionSS,
    float3 positionWS,
    float3 normalWS,
    int shadowIndex,
    float3 L,
    float2 jitterOffset)
{
    // 获取阴影坐标（需要根据实际 shadow 架构调整）
    HDShadowData sd = _HDShadowDatas[shadowIndex];

    // 计算世界空间到阴影空间的变换
    float4 shadowCoord = mul(float4(positionWS, 1), sd.worldToShadow);

    // 应用 Blue Noise 抖动到阴影 UV
    shadowCoord.xy += jitterOffset * _CascadeShadowAtlasSize.zw;

    // 执行阴影采样（使用 ULTRA_LOW 的 Gather 方法）
    return SampleShadow_Gather_PCF(_CascadeShadowAtlasSize.zwxy,
                                   shadowCoord.xyz,
                                   _CascadeShadowAtlas,
                                   s_point_clamp_sampler,
                                   0);
}
```

---

## 方案二：Multi-sample Blue Noise Shadow（更高质量但性能开销更大）

如果需要更高的质量，可以进行多次 Blue Noise 加权的阴影采样：

### 修改 EvaluateVoxelLightingDirectional 中的阴影采样

```hlsl
// 多次 Blue Noise 阴影采样
float totalShadow = 0;
const int sampleCount = 4; // 采样数量

[unroll]
for (int s = 0; s < sampleCount; s++)
{
    // 使用不同的 blue noise 偏移进行多次采样
    float2 blueNoiseOffset = SampleBlueNoise2D(posInput.positionSS, _VBufferSampleOffset.z + s * 0.25);
    float2 jitter = (blueNoiseOffset * 2.0 - 1.0) * _VolumetricShadowFilterWidth;

    float shadow = GetDirectionalShadowAttenuationWithJitter(
        context.shadowContext,
        posInput.positionSS,
        positionWS,
        shadowN,
        light.shadowIndex,
        L,
        jitter);

    totalShadow += shadow;
}

context.shadowValue = totalShadow / sampleCount;
```

---

## 方案三：利用现有的 BND Sequence（最佳方案）

HDRP 已有 `GetBNDSequenceSample` 函数，这是最完整的 Blue Noise 实现。

### 1. 在 VolumetricLighting.compute 顶部添加 include

```hlsl
// 在头部 includes 区域添加
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/Raytracing/Shaders/RaytracingSampling.hlsl"
```

### 2. 添加 Blue Noise 阴影抖动函数

```hlsl
// 使用 BND Sequence 获取阴影抖动值
float2 GetBlueNoiseShadowJitter2D(uint2 pixelCoord, uint frameIndex)
{
    // 使用不同维度获取两个独立的 blue noise 值
    float jitterX = GetBNDSequenceSample(pixelCoord, frameIndex & 255, 0);
    float jitterY = GetBNDSequenceSample(pixelCoord, frameIndex & 255, 1);

    // 转换到 [-1, 1] 范围
    return float2(jitterX, jitterY) * 2.0 - 1.0;
}

// 或者使用极坐标形式（视觉上效果更好）
float2 GetBlueNoiseShadowJitterPolar(uint2 pixelCoord, uint frameIndex)
{
    float angle = GetBNDSequenceSample(pixelCoord, frameIndex & 255, 0) * TWO_PI;
    float radius = GetBNDSequenceSample(pixelCoord, frameIndex & 255, 1);

    // 使用泊松盘分布的半径
    radius = sqrt(radius);

    return float2(cos(angle), sin(angle)) * radius;
}
```

### 3. 在 EvaluateVoxelLightingDirectional 中使用

```hlsl
// 使用 BND Sequence 生成阴影采样偏移
float2 shadowJitter = GetBlueNoiseShadowJitterPolar(posInput.positionSS, (uint)_VBufferSampleOffset.z);
shadowJitter *= _VolumetricShadowJitterScale;

// 应用到阴影采样
context.shadowValue = GetDirectionalShadowAttenuationWithJitter(
    context.shadowContext,
    posInput.positionSS,
    posInput.positionWS,
    shadowN,
    light.shadowIndex,
    L,
    shadowJitter
);
```

---

## C# 端修改

### 1. 修改 VolumetricLightingPassData 类

在 `HDRenderPipeline.VolumetricLighting.cs` 中找到 `VolumetricLightingPassData` 类（约第 1302 行）：

```csharp
class VolumetricLightingPassData
{
    public ComputeShader volumetricLightingCS;
    public ComputeShader volumetricLightingFilteringCS;
    public int volumetricLightingKernel;
    public int volumetricFilteringKernel;
    public bool tiledLighting;
    public Vector4 resolution;
    public bool enableReprojection;
    public int viewCount;
    public int sliceCount;
    public bool filterVolume;
    public bool filteringNeedsExtraBuffer;
    public ShaderVariablesVolumetric volumetricCB;
    public ShaderVariablesLightList lightListCB;

    public TextureHandle densityBuffer;
    public TextureHandle depthTexture;
    public TextureHandle lightingBuffer;
    public TextureHandle filteringOutputBuffer;
    public TextureHandle maxZBuffer;
    public TextureHandle historyBuffer;
    public TextureHandle feedbackBuffer;
    public BufferHandle bigTileVolumetricLightListBuffer;
    public GraphicsBuffer volumetricAmbientProbeBuffer;

    // Underwater
    public bool water;
    public BufferHandle waterLine;
    public BufferHandle waterCameraHeight;
    public TextureHandle waterStencil;
    public RenderTargetIdentifier causticsBuffer;

    // === 新增：Blue Noise 阴影抖动参数 ===
    public float volumetricShadowJitterScale;   // 控制 Blue Noise 偏移范围
    public TextureHandle blueNoiseTexture;      // Blue Noise 纹理（方案一、二用）
    public bool useBlueNoiseShadowDither;       // 是否启用 Blue Noise 阴影抖动
}
```

### 2. 在 VolumetricLightingPass 函数中设置参数

在 `VolumetricLightingPass` 函数（约第 1336 行）中添加：

```csharp
TextureHandle VolumetricLightingPass(RenderGraph renderGraph, HDCamera hdCamera,
    TextureHandle depthTexture, TextureHandle densityBuffer,
    TextureHandle maxZBuffer, in TransparentPrepassOutput transparentPrepass,
    TextureHandle depthBuffer, BufferHandle bigTileVolumetricLightListBuffer, ShadowResult shadowResult)
{
    if (Fog.IsVolumetricFogEnabled(hdCamera))
    {
        using (var builder = renderGraph.AddRenderPass<VolumetricLightingPassData>("Volumetric Lighting", out var passData))
        {
            // ... 现有代码 ...

            // === 新增：Blue Noise 阴影抖动设置 ===
            passData.useBlueNoiseShadowDither = true;
            passData.volumetricShadowJitterScale = 1.5f; // 可调节，控制抖动范围

            // 使用 HDRP 内置的 Blue Noise 纹理
            // 注意：需要在 HDRenderPipeline 中获取 m_BlueNoise 引用
            passData.blueNoiseTexture = renderGraph.ImportTexture(m_BlueNoise.textureArray16L);

            // ... 现有代码 ...
        }
    }
    // ...
}
```

### 3. 在 RenderFunc 中绑定参数

在 `builder.SetRenderFunc` 部分（约第 1426 行）添加：

```csharp
builder.SetRenderFunc(
    (VolumetricLightingPassData data, RenderGraphContext ctx) =>
    {
        // ... 现有代码 ...

        // === 新增：Blue Noise 阴影抖动参数绑定 ===
        if (data.useBlueNoiseShadowDither)
        {
            ctx.cmd.SetComputeTextureParam(data.volumetricLightingCS, data.volumetricLightingKernel,
                HDShaderIDs._BlueNoiseTexture, data.blueNoiseTexture);
            ctx.cmd.SetComputeFloatParam(data.volumetricLightingCS,
                HDShaderIDs._VolumetricShadowJitterScale, data.volumetricShadowJitterScale);
        }

        // ... 现有代码 ...
    });
```

### 4. 添加 Shader 变量 ID

在 `HDStringConstants.cs` 中添加：

```csharp
// 在 ShaderID 类中添加
public static readonly int _BlueNoiseTexture = Shader.PropertyToID("_BlueNoiseTexture");
public static readonly int _VolumetricShadowJitterScale = Shader.PropertyToID("_VolumetricShadowJitterScale");
```

---

## 工作原理

### Blue Noise 特性
- **低频能量集中**：低频成分很少，意味着大面积的误差块很少出现
- **高频能量分散**：高频成分均匀分布，噪声在视觉上更加随机和自然
- **各向同性**：在所有方向上具有相同的统计特性

### 时域累积
VolumetricLighting 已有 Temporal Reprojection 机制（`ENABLE_REPROJECTION` 宏）：

```hlsl
// VolumetricLighting.compute 中的时域混合
float historyWeight = ComputeHistoryWeight(); // 约 0.857
normalizedBlendValue = lerp(normalizedVoxelValue, reprojValue, historyWeight);
```

Blue Noise 每帧使用不同的偏移，多帧累积后噪声逐渐收敛。

### 空间抖动
每帧使用不同的 Blue Noise 偏移采样阴影，避免固定模式的锯齿（aliasing）。

```
Frame N:   ShadowSample(position + blueNoiseOffset_N)
Frame N+1: ShadowSample(position + blueNoiseOffset_N+1)
Frame N+2: ShadowSample(position + blueNoiseOffset_N+2)
...
Temporal Accumulation → Converged Result
```

---

## 性能考虑

| 方案 | 额外 GPU 开销 | 内存开销 | 降噪效果 | 收敛速度 |
|------|--------------|---------|---------|---------|
| 方案一：单次 Blue Noise Jitter | 极小（~1-2条指令） | 无额外 | 需要时域累积 | 4-8帧 |
| 方案二：4x Multi-sample | 4x 采样开销 | 无额外 | 立即生效 | 1帧 |
| 方案三：BND Sequence | 小（使用现有纹理） | 需绑定额外纹理 | 最佳时域收敛 | 2-4帧 |

### 推荐选择

1. **性能优先**：使用���案一或方案三，开销最小
2. **质量优先**：使用方案二，但需要注意性能
3. **最佳平衡**：使用方案三配合现有的 Temporal Reprojection

### 注意事项

1. **抖动范围**：`_VolumetricShadowJitterScale` 参数需要根据阴影贴图分辨率调整
   - 高分辨率阴影：可以使用较大的值（1.5-2.0）
   - 低分辨率阴影：使用较小的值（0.5-1.0）

2. **时域稳定性**：如果场景或相机移动较快，可能需要调整 `ComputeHistoryWeight` 中的 `numFrames` 参数

3. **与 Gaussian Filtering 的配合**：HDRP 已有的 `FogDenoisingMode.Gaussian` 可以与 Blue Noise 同时使用，获得更好的降噪效果

---

## 快速开始：最小修改方案

如果只想快速测试，只需修改 `VolumetricLighting.compute` 一个文件：

### 步骤 1：在文件头部添加

```hlsl
// 在 Inputs & outputs 部分后添加
TEXTURE2D(_BlueNoiseTexture);
SAMPLER(s_linear_repeat_sampler);
float _VolumetricShadowJitterScale;
```

### 步骤 2：修改 EvaluateVoxelLightingDirectional 中的阴影采样

找到第 198-200 行，修改为：

```hlsl
// 使用屏幕空间坐标生成 blue noise 偏移
float2 noiseUV = float2(posInput.positionSS & 127) / 128.0;
float blueNoise = SAMPLE_TEXTURE2D_LOD(_BlueNoiseTexture, s_linear_repeat_sampler, noiseUV, 0).r;
float angle = blueNoise * TWO_PI;
float2 shadowJitter = float2(cos(angle), sin(angle)) * _VolumetricShadowJitterScale;

// 在采样阴影时可以添加偏移（需要修改 GetDirectionalShadowAttenuation 或使用其他方法）
context.shadowValue = GetDirectionalShadowAttenuation(context.shadowContext,
                                                      posInput.positionSS, posInput.positionWS, shadowN,
                                                      light.shadowIndex, L);
```

### 步骤 3：在 C# 端绑定 Blue Noise 纹理

在 `HDRenderPipeline.VolumetricLighting.cs` 的 `VolumetricLightingPass` 中：

```csharp
// 在 SetRenderFunc 内部添加
ctx.cmd.SetComputeTextureParam(data.volumetricLightingCS, data.volumetricLightingKernel,
    "_BlueNoiseTexture", m_BlueNoise.textures16L[0]);
ctx.cmd.SetComputeFloatParam(data.volumetricLightingCS,
    "_VolumetricShadowJitterScale", 1.0f);
```

---

## 参考资源

1. **Blue Noise Paper**: "A Low-Discrepancy Sampler that Distributes Monte Carlo Errors as a Blue Noise in Screen Space" - Heitz et al.
2. **Unity HDRP Volumetric Clouds**: 已使用 Blue Noise 进行 ray marching 抖动
3. **HDRP Raytracing Sampling**: `RaytracingSampling.hlsl` 中有完整的 BND 实现

---

# 调试与分析指南

## 1. 渲染管线完整流程

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. VolumetricLighting.compute (GPU Compute)                          │
│    - 逐体素计算 (行 629-785 的循环)                                  │
│    - 采样密度、评估光源、采样阴影                                    │
│    - 输出到 3D Texture: _VBufferLighting                            │
│    - 蓝噪声优化在行 244-257 (方向光阴影采样)                         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 2. AtmosphericScattering.hlsl (Fragment Shader)                    │
│    - SampleVBuffer() 读取 3D 纹理 (行 288-296)                     │
│    - 进行重建和 Delinearize 处理 (行 300)                           │
│    - 输出 volColor, volOpacity                                      │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3. OpaqueAtmosphericScattering.shader (Full Screen Pass)           │
│    - 调用 EvaluateAtmosphericScattering (行 140)                  │
│    - 与表面颜色合成 (OutputFog 函数)                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 模块划分

```
VolumetricLighting.compute
│
├── 1. 工具函数区 (行 92-199)
│   ├── EvaluateVolumetricAmbientProbe (行 92)
│   ├── GetBlueNoiseShadowJitter2D (行 158) - 蓝噪声抖动
│   ├── GetBlueNoiseShadowJitterPolar (行 169) - 极坐标抖动
│   └── GetDirectionalShadowAttenuationWithBlueNoise (行 184)
│
├── 2. 方向光评估 (行 203-344)
│   ├── 阴影采样 (行 244-257) ← 蓝噪声优化目标
│   └── 光照计算 + 相位函数
│
├── 3. 局部光评估 (行 348-541)
│   ├── 射线-锥体/盒体相交检测
│   ├── 阴影采样 (行 438)
│   └── 光照计算
│
└── 4. 主入口 (行 585-843)
    └── FillVolumetricLightingBuffer - 逐体素循环
```

---

## 3. 调试开关使用指南

### 3.1 VolumetricLighting.compute 中的调试

在 `FillVolumetricLightingBuffer` 函数中添加调试输出：

```hlsl
// 行 692 附近，在 perPixelRandomOffset 计算后：

#ifdef DEBUG_OUTPUT
// 输出当前使用的随机噪声值
_VBufferLighting[voxelCoord] = max(0, float4(perPixelRandomOffset.xxx, 1.0) * float4(GetCurrentExposureMultiplier().xxx, 1));
#endif
```

启用方式：在文件顶部添加
```hlsl
#define DEBUG_OUTPUT 1
```

### 3.2 AtmosphericScattering.hlsl 中的调试

在 `SampleVBuffer` 调用后（行 288-300）添加：

```hlsl
// 临时输出 VBuffer 原始值进行调试
#ifdef DEBUG_VBUFFER_SAMPLE
color = value.rgb * 50.0;  // 放大显示
opacity = 1.0;
return true;
#endif
```

---

## 4. 蓝噪声 vs 哈希随机数 对比

### 4.1 两种噪声的定义

#### GenerateHashedRandomFloat (当前使用的哈希随机数)
- **位置**: `Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl:62`
- **算法**: Jenkins Hash
- **特点**: 均匀分布的伪随机数，但相邻像素之间相关性较高

```hlsl
float GenerateHashedRandomFloat(uint2 v)
{
    return ConstructFloat(JenkinsHash(v));
}
```

#### GetBNDSequenceSample (蓝噪声 BND Sequence)
- **位置**: `Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/Raytracing/Shaders/RaytracingSampling.hlsl:57`
- **算法**: Owen-Scrambled Blue Noise Sequence
- **特点**: 相邻像素的误差呈蓝噪声分布，高频噪声更适合时域累积

```hlsl
float GetBNDSequenceSample(uint2 pixelCoord, uint sampleIndex, uint sampleDimension)
{
    // wrap arguments
    pixelCoord = pixelCoord & 127;
    sampleIndex = sampleIndex & 255;
    sampleDimension = sampleDimension & 255;

    // xor index based on optimized ranking
    uint rankingIndex = (pixelCoord.x + pixelCoord.y * 128) * 8 + (sampleDimension & 7);
    uint rankedSampleIndex = sampleIndex ^ clamp((uint)(_RankingTileXSPP[uint2(rankingIndex & 127, rankingIndex / 128)] * 256.0), 0, 255);

    // fetch value in sequence
    uint value = clamp((uint)(_OwenScrambledTexture[uint2(sampleDimension, rankedSampleIndex.x)] * 256.0), 0, 255);

    // If the dimension is optimized, xor sequence value based on optimized scrambling
    uint scramblingIndex = (pixelCoord.x + pixelCoord.y * 128) * 8 + (sampleDimension & 7);
    float scramblingValue = min(_ScramblingTileXSPP[uint2(scramblingIndex & 127, scramblingIndex / 128)], 0.999);
    value = value ^ uint(scramblingValue * 256.0);

    // Convert to float (to avoid the same 1/256th quantization everywhere, we jitter by the pixel scramblingValue)
    return (scramblingValue + value) / 256.0;
}
```

### 4.2 对比方法

#### 方法 1: 直接输出噪声纹理对比

在 `FillVolumetricLightingBuffer` 中分别输出两种噪声进行对比：

```hlsl
// 输出 GenerateHashedRandomFloat (哈希随机数) - 当前使用的
float hashNoise = GenerateHashedRandomFloat(posInput.positionSS);
#ifdef DEBUG_OUTPUT_HASH
_VBufferLighting[voxelCoord] = float4(hashNoise, hashNoise, hashNoise, 1.0);
continue;
#endif

// 输出 GetBNDSequenceSample (蓝噪声) - 你添加的优化
float bnNoiseX = GetBNDSequenceSample(posInput.positionSS, (uint)_VBufferSampleOffset.z & 255, 0);
float bnNoiseY = GetBNDSequenceSample(posInput.positionSS, (uint)_VBufferSampleOffset.z & 255, 1);
#ifdef DEBUG_OUTPUT_BN
_VBufferLighting[voxelCoord] = float4(bnNoiseX, bnNoiseY, 0, 1.0);
continue;
#endif
```

#### 方法 2: 使用 RenderDoc 对比

1. 捕获两个帧：一个使用哈希随机数，一个使用蓝噪声
2. 对比 VBuffer 3D 纹理的输出
3. 观察噪声的空间分布

#### 方法 3: 观察时域稳定性

1. 固定相机和场景
2. 记录多帧的体积雾边缘
3. 对比两种噪声的闪烁程度

---

## 5. 蓝噪声抖动参数说明

在 `VolumetricLighting.compute` 中（行 169-178）：

```hlsl
float2 GetBlueNoiseShadowJitterPolar(uint2 pixelCoord, uint frameIndex)
{
    float angle = GetBNDSequenceSample(pixelCoord, frameIndex & 255, 0) * TWO_PI;
    float radius = GetBNDSequenceSample(pixelCoord, frameIndex & 255, 1);
    radius = sqrt(radius);
    return float2(cos(angle), sin(angle)) * radius;
}
```

- **angle**: 使用维度 0，生成 [0, 2π) 的角度
- **radius**: 使用维度 1，生成 [0, 1) 的半径，sqrt 使其更均匀
- **frameIndex**: 低 8 位，256 帧循环
- **返回值**: 极坐标形式的 2D 抖动偏移

---

## 6. 调试建议流程

1. **先验证噪声本身是否正确生成**
   - 输出纯噪声纹理到 VBuffer
   - 用 RenderDoc 或截图确认噪声模式

2. **分离其他因素影响**
   - 只保留方向光
   - 设置均匀的密度场

3. **对比有/无抖动的效果**
   - 创建一个 C# 参数控制开关

4. **观察时域累积效果**
   - 开启/关闭抖动，对比边缘稳定性

---

## 7. 相关文件索引

| 文件 | 路径 | 用途 |
|------|------|------|
| VolumetricLighting.compute | Runtime/Lighting/VolumetricLighting/ | 体积光计算核心 |
| VBuffer.hlsl | Runtime/Lighting/VolumetricLighting/ | VBuffer 采样 |
| AtmosphericScattering.hlsl | Runtime/Lighting/AtmosphericScattering/ | 大气散射计算 |
| OpaqueAtmosphericScattering.shader | Runtime/Lighting/AtmosphericScattering/ | 最终合成 |
| Random.hlsl | ../../../render-pipelines.core/ShaderLibrary/ | 哈希随机数 |
| RaytracingSampling.hlsl | Runtime/RenderPipeline/Raytracing/Shaders/ | 蓝噪声序列 |

---

## 8. 常见问题

### Q: 调试输出全是黑色？
A: 检查 `GetCurrentExposureMultiplier()` 是否正确，可能需要乘以较大倍数（如 10-100）才能看到。

### Q: 如何看到 VBuffer 的 3D 结构？
A: 用 RenderDoc 的 3D Texture Viewer 查看不同切片（slice）。

### Q: 蓝噪声效果不如预期？
A: 检查 `_VolumetricShadowJitterScale` 参数，可能需要调整抖动幅度。

### Q: 哈希随机数和蓝噪声的区别？
A: 哈希随机数是均匀分布但空间相关性高，蓝噪声是高频噪声适合时域累积。蓝噪声在多帧累积时收敛更快、效果更平滑。
