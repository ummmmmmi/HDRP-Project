// =============================================================================
// 体积雾数据生成 - 顶点着色器（还原版本）
// =============================================================================
// 本顶点着色器用于计算体积雾光线步进的射线参数。
// 它变换顶点并计算雾盒相交参数，然后传递给片段着色器。
//
// 输入: 全屏四边形或体积包围盒顶点
// 输出: 变换后的位置和射线-盒相交参数
// =============================================================================

// 常量缓冲区
cbuffer CB0 : register(b0)
{
    float4 cb0[38];

    // cb0[6-9] - 雾体积中心的模型视图投影矩阵
    // cb0[17-20] - 顶点位置变换的 MVP 矩阵
    // cb0[21-24] - 世界空间位置的模型矩阵
    // cb0[30-33] - 射线起始位置变换
    // cb0[34-36] - 视图矩阵（相机到世界）
    // cb0[37] - 雾体积盒参数（最小角、缩放、最大角、?）
};

// =============================================================================
// 顶点着色器输入
// =============================================================================
struct VSInput
{
    float4 position : POSITION0;    // 顶点位置
    float3 normal : NORMAL0;        // 顶点法线（未使用）
    float4 texCoord : TEXCOORD0;    // 纹理坐标（未使用）
};

// =============================================================================
// 顶点着色器输出
// =============================================================================
struct VSOutput
{
    float4 svPosition : SV_POSITION0;    // 变换后的位置
    float4 rayParams : TEXCOORD0;        // 射线参数 (tNear, 0, 0, 1)
    float4 boxStartCoeffs : TEXCOORD1;   // 盒相交起始系数
    float4 boxStartPos : TEXCOORD2;      // 盒相交起始位置
    float4 boxEndCoeffs : TEXCOORD3;     // 盒相交结束系数
    float4 boxEndPos : TEXCOORD4;        // 盒相交结束位置
    float4 volumeParams : TEXCOORD5;     // 体积参数
};

// =============================================================================
// 主顶点着色器
// =============================================================================
VSOutput main(VSInput input)
{
    VSOutput output;

    // ============================================================
    // 第一步: 将顶点位置变换到裁剪空间
    // ============================================================
    // 标准 MVP 变换: position_clip = Projection * ModelView * position_local
    // cb0[17-20] 包含组合的 MVP 矩阵

    float4 mvpTransform;
    mvpTransform = cb0[18] * input.position.yyyy;
    mvpTransform = cb0[17] * input.position.xxxx + mvpTransform;
    mvpTransform = cb0[19] * input.position.zzzz + mvpTransform;
    output.svPosition = cb0[20] * input.position.wwww + mvpTransform;

    // ============================================================
    // 第二步: 将顶点位置变换到世界空间
    // ============================================================
    // 世界空间位置用于射线方向计算
    // cb0[21-24] 包含模型矩阵

    float3 worldPos;
    worldPos = cb0[22].xyz * input.position.yyy;
    worldPos = cb0[21].xyz * input.position.xxx + worldPos;
    worldPos = cb0[23].xyz * input.position.zzz + worldPos;
    worldPos = cb0[24].xyz * input.position.www + worldPos;

    // ============================================================
    // 第三步: 计算射线方向和参数
    // ============================================================
    // 射线从相机穿过顶点在世界空间中
    // 我们需要计算这条射线与雾体积盒的相交点

    // tNear 是沿射线到雾体积的距离
    float tNear = -worldPos.z;

    // 计算视图空间中的射线方向（用 z 归一化）
    // 这为我们提供了相交测试的射线方向
    float2 rayDirXY = -worldPos.xy / worldPos.zz;

    // ============================================================
    // 第四步: 将射线方向变换到相机空间
    // ============================================================
    // cb0[34-36] 包含视图矩阵（相机到世界变换）
    // 我们将射线方向从视图空间变换到相机空间

    float3 cameraDir;
    cameraDir = cb0[35].xyz * rayDirXY.yyy;
    cameraDir = cb0[34].xyz * rayDirXY.xxx + cameraDir;
    cameraDir = cb0[36].xyz + cameraDir;

    // ============================================================
    // 第五步: 计算盒相交起始位置
    // ============================================================
    // 用模型视图矩阵变换相机方向
    // cb0[6-8] 包含模型视图矩阵

    float4 mvTransformStart;
    mvTransformStart = cb0[7] * cameraDir.yyyy;
    mvTransformStart = cb0[6] * cameraDir.xxxx + mvTransformStart;
    mvTransformStart = cb0[8] * cameraDir.zzzz + mvTransformStart;

    // 用 tNear 缩放得到实际起始位置
    output.boxStartPos = mvTransformStart * tNear.zzzz;

    // ============================================================
    // 第六步: 计算盒相交结束位置
    // ============================================================
    // 结束位置使用雾体积盒参数计算
    // cb0[37] 包含盒参数（最小、缩放、最大、?）
    // cb0[9] 包含平移偏移

    float4 mvTransformEnd;
    mvTransformEnd = cb0[37].yyyy * cb0[7];
    mvTransformEnd = cb0[6] * cb0[37].xxxx + mvTransformEnd;
    mvTransformEnd = cb0[8] * cb0[37].zzzz + mvTransformEnd;
    output.boxEndCoeffs = cb0[9] * cb0[37].wwww + mvTransformEnd;

    // ============================================================
    // 第七步: 计算盒相交系数
    // ============================================================
    // 这些系数定义雾体积盒的 4 个平面
    // cb0[30-33] 包含起始位置的变换

    float4 boxCoeffs;
    boxCoeffs = cb0[31] * rayDirXY.yyyy;
    boxCoeffs = cb0[30] * rayDirXY.xxxx + boxCoeffs;
    boxCoeffs = cb0[32] + boxCoeffs;
    output.boxStartCoeffs = boxCoeffs * tNear.zzzz;

    // ============================================================
    // 第八步: 输出射线参数
    // ============================================================
    // tNear 是到雾体积的归一化距离
    // 这在片段着色器中用于计算光线步进区间
    output.rayParams.x = tNear;
    output.rayParams.yz = 0.0;
    output.rayParams.w = 1.0;

    // ============================================================
    // 第九步: 输出体积参数
    // ============================================================
    // cb0[33] 包含额外的体积参数
    // 这些可能用于密度计算或其他效果
    output.volumeParams = cb0[33];

    return output;
}
