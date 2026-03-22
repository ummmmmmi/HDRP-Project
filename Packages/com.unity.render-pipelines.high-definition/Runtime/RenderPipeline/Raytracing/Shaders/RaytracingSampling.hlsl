#ifndef UNITY_RAYTRACING_SAMPLING_INCLUDED
#define UNITY_RAYTRACING_SAMPLING_INCLUDED

Texture2D<float>  _OwenScrambledTexture;
Texture2D<float>  _ScramblingTileXSPP;
Texture2D<float>  _RankingTileXSPP;
Texture2D<float2> _ScramblingTexture;

float ScramblingValueFloat(uint2 pixelCoord)
{
    pixelCoord = pixelCoord & 255;
    return _ScramblingTexture[uint2(pixelCoord.x, pixelCoord.y)].x;
}

float2 ScramblingValueFloat2(uint2 pixelCoord)
{
    pixelCoord = pixelCoord & 255;
    return _ScramblingTexture[uint2(pixelCoord.x, pixelCoord.y)].xy;
}

uint ScramblingValueUInt(uint2 pixelCoord)
{
    pixelCoord = pixelCoord & 255;
    return clamp((uint)(_ScramblingTexture[uint2(pixelCoord.x, pixelCoord.y)].x * 256.0), 0, 255);
}

uint2 ScramblingValueUInt2(uint2 pixelCoord)
{
    pixelCoord = pixelCoord & 255;
    return clamp((uint2)(_ScramblingTexture[uint2(pixelCoord.x, pixelCoord.y)] * 256.0), uint2(0,0), uint2(255, 255));
}

// Wrapper to sample the scrambled low Low-Discrepancy sequence (returns a float)
float GetLDSequenceSampleFloat(uint sampleIndex, uint sampleDimension)
{
    // Make sure arguments are in the right range
    sampleIndex = sampleIndex & 255;
    // sampleDimension = sampleDimension & 255;

    // Fetch the sequence value and return it
    return _OwenScrambledTexture[uint2(sampleDimension, sampleIndex)];
}

// Wrapper to sample the scrambled low Low-Discrepancy sequence (returns an unsigned int)
uint GetLDSequenceSampleUInt(uint sampleIndex, uint sampleDimension)
{
    // Make sure arguments are in the right range
    sampleIndex = sampleIndex & 255;
    // sampleDimension = sampleDimension & 255;

    // Fetch the sequence value and return it
    return clamp((uint)(_OwenScrambledTexture[uint2(sampleDimension, sampleIndex)] * 256.0), 0, 255);
}

// This is an implementation of the method from the paper
// "A Low-Discrepancy Sampler that Distributes Monte Carlo Errors as a Blue Noise in Screen Space" by Heitz et al.
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

// =============================================================================
// 时序蓝噪声采样（INSIDE 风格）
// =============================================================================
// 仅 1 次纹理采样，用质数混合时间和像素坐标，每帧获得不同的蓝噪声图案
// 参考自 INSIDE 的体积雾实现

// 获取时序蓝噪声（float 版本，��� 1 次纹理采样）
// time: 通常是帧号或 _Time.y
// 返回: [0, 1) 范围的蓝噪声值
float GetTemporalBlueNoiseFloat(uint2 pixelCoord, float time)
{
    // INSIDE 风格：用质数计算时间偏移，然后加到像素坐标上
    // 这样相邻像素保持 1:1 对应，只是噪声图案整体平移
    uint timeOffsetX = uint(time * 1259.0) & 255;  // 1259 是质数
    uint timeOffsetY = uint(time * 1277.0) & 255;  // 1277 是质数

    // 像素坐标 + 时间偏移，保持 1:1 的像素对应关系
    uint2 noiseCoord = (pixelCoord + uint2(timeOffsetX, timeOffsetY)) & 255;
    return _ScramblingTexture[noiseCoord].x;
}

// 获取时序蓝噪声（float2 版本，仅 1 次纹理采样）
float2 GetTemporalBlueNoiseFloat2(uint2 pixelCoord, float time)
{
    uint timeOffsetX = uint(time * 1259.0) & 255;
    uint timeOffsetY = uint(time * 1277.0) & 255;

    uint2 noiseCoord = (pixelCoord + uint2(timeOffsetX, timeOffsetY)) & 255;
    return _ScramblingTexture[noiseCoord].xy;
}

#endif // UNITY_RAYTRACING_SAMPLING_INCLUDED
