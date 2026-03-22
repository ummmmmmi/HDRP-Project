cbuffer CB0UBO : register(b0)
{
    float4 CB0_m0[17] : packoffset(c0);
};

cbuffer CB1UBO : register(b1)
{
    float4 CB1_m0[8] : packoffset(c0);
};

Texture2D<float4> T0 : register(t0);
Texture2D<float4> T1 : register(t1);
Texture2D<float4> T2 : register(t2);
Texture2D<float4> T3 : register(t3);
Texture2D<float4> T4 : register(t4);
Texture2D<float4> T5 : register(t5);
SamplerComparisonState S0 : register(s0);
SamplerState S1 : register(s1);
SamplerState S2 : register(s2);
SamplerState S3 : register(s3);

static float4 gl_FragCoord;
static float TEXCOORD;
static float4 TEXCOORD_1;
static float4 TEXCOORD_2;
static float4 TEXCOORD_3;
static float4 TEXCOORD_4;
static float4 SV_Target;

struct SPIRV_Cross_Input
{
    float TEXCOORD : TEXCOORD1;
    float4 TEXCOORD_1 : TEXCOORD2;
    float4 TEXCOORD_2 : TEXCOORD3;
    float4 TEXCOORD_3 : TEXCOORD4;
    float4 TEXCOORD_4 : TEXCOORD5;
    float4 gl_FragCoord : SV_Position;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

static bool discard_state;

void discard_cond(bool _400)
{
    if (_400)
    {
        discard_state = true;
    }
}

void discard_exit()
{
    if (discard_state)
    {
        discard;
    }
}

void frag_main()
{
    discard_state = false;
    uint _58 = uint(int(gl_FragCoord.x));
    uint _59 = uint(int(gl_FragCoord.y));
    float4 _60 = T5.Load(int3(uint2(_58, _59), 0u));
    float _63 = _60.x;
    precise float _72 = _63 * CB1_m0[5u].z;
    precise float _82 = 1.0f / mad(CB1_m0[7u].z, T4.Load(int3(uint2(_58, _59), 0u)).x, CB1_m0[7u].w);
    precise float _87 = (-0.0f) - _82;
    discard_cond(mad(CB1_m0[5u].z, _63, _87) < 0.0f);
    precise float _113 = mad(CB0_m0[15u].w, 1201.0f, gl_FragCoord.x) * CB0_m0[16u].z;
    precise float _114 = mad(CB0_m0[15u].w, 1291.0f, gl_FragCoord.y) * CB0_m0[16u].w;
    float4 _117 = T0.SampleLevel(S3, float2(_113, _114), 0.0f);
    float _120 = _117.x;
    float _123 = min(_72, _82);
    float _125 = min(_72, TEXCOORD);
    precise float _137 = (-0.0f) - TEXCOORD;
    precise float _138 = TEXCOORD_1.x / _137;
    precise float _139 = TEXCOORD_1.y / _137;
    precise float _140 = TEXCOORD_1.z / _137;
    precise float _141 = TEXCOORD_1.w / _137;
    float _150 = mad(_123, _138, TEXCOORD_2.x);
    float _151 = mad(_123, _139, TEXCOORD_2.y);
    float _152 = mad(_123, _140, TEXCOORD_2.z);
    float _153 = mad(_123, _141, TEXCOORD_2.w);
    precise float _166 = (-0.0f) - _150;
    precise float _167 = (-0.0f) - _151;
    precise float _168 = (-0.0f) - _152;
    precise float _169 = (-0.0f) - _153;
    precise float _170 = _166 + mad(_125, _138, TEXCOORD_2.x);
    precise float _171 = _167 + mad(_125, _139, TEXCOORD_2.y);
    precise float _172 = _168 + mad(_125, _140, TEXCOORD_2.z);
    precise float _173 = _169 + mad(_125, _141, TEXCOORD_2.w);
    precise float _174 = _170 * 0.16666667163372039794921875f;
    precise float _176 = _171 * 0.16666667163372039794921875f;
    precise float _177 = _172 * 0.16666667163372039794921875f;
    precise float _178 = _173 * 0.16666667163372039794921875f;
    float _179 = mad(_120, _174, _150);
    float _180 = mad(_120, _176, _151);
    float _181 = mad(_120, _177, _152);
    float _182 = mad(_120, _178, _153);
    precise float _192 = (-0.0f) - TEXCOORD;
    precise float _193 = TEXCOORD_3.x / _192;
    precise float _194 = TEXCOORD_3.y / _192;
    precise float _195 = TEXCOORD_3.z / _192;
    precise float _196 = TEXCOORD_3.w / _192;
    float _205 = mad(_123, _193, TEXCOORD_4.x);
    float _206 = mad(_123, _194, TEXCOORD_4.y);
    float _207 = mad(_123, _195, TEXCOORD_4.z);
    float _208 = mad(_123, _196, TEXCOORD_4.w);
    precise float _221 = (-0.0f) - _205;
    precise float _222 = (-0.0f) - _206;
    precise float _223 = (-0.0f) - _207;
    precise float _224 = (-0.0f) - _208;
    precise float _225 = _221 + mad(_125, _193, TEXCOORD_4.x);
    precise float _226 = _222 + mad(_125, _194, TEXCOORD_4.y);
    precise float _227 = _223 + mad(_125, _195, TEXCOORD_4.z);
    precise float _228 = _224 + mad(_125, _196, TEXCOORD_4.w);
    precise float _229 = _225 * 0.16666667163372039794921875f;
    precise float _230 = _226 * 0.16666667163372039794921875f;
    precise float _231 = _227 * 0.16666667163372039794921875f;
    precise float _232 = _228 * 0.16666667163372039794921875f;
    float _233 = mad(_120, _229, _205);
    float _234 = mad(_120, _230, _206);
    float _235 = mad(_120, _231, _207);
    float _236 = mad(_120, _232, _208);
    precise float _237 = _179 / _182;
    precise float _238 = _180 / _182;
    precise float _239 = _181 / _182;
    precise float _251 = (-0.0f) - CB0_m0[14u].x;
    precise float _253 = (-0.0f) - CB0_m0[14u].z;
    precise float _254 = _251 + 1.0f;
    precise float _255 = _253 + 1.0f;
    float _266 = asfloat(1056964608u);
    precise float _275 = _233 / _236;
    precise float _276 = _234 / _236;
    precise float _277 = _275 + 0.5f;
    precise float _279 = _276 + 0.5f;
    precise float _287 = mad(T3.SampleCmpLevelZero(S0, float2(_237, _238), _239).xxxx.x, CB0_m0[14u].z, _255) * T2.SampleLevel(S1, float2(_277, _279), CB0_m0[14u].y).w;
    precise float _288 = mad(_254, T1.SampleLevel(S2, float2(dot(float3(_233, _234, _235), float3(_233, _234, _235)), asfloat(1056964608u)), 0.0f).x, CB0_m0[14u].x) * _287;
    float _307;
    _307 = _288;
    float _292;
    float _294;
    float _296;
    float _298;
    float _300;
    float _302;
    float _304;
    float _306;
    precise float _359;
    precise float _360;
    precise float _361;
    precise float _382;
    precise float _383;
    precise float _384;
    precise float _385;
    precise float _393;
    uint _289 = 1u;
    float _291 = _179;
    float _293 = _180;
    float _295 = _181;
    float _297 = _182;
    float _299 = _233;
    float _301 = _234;
    float _303 = _235;
    float _305 = _236;
    for (; !(int(_289) >= int(6u)); _300 = mad(_225, 0.16666667163372039794921875f, _299), _302 = mad(_226, 0.16666667163372039794921875f, _301), _304 = mad(_227, 0.16666667163372039794921875f, _303), _306 = mad(_228, 0.16666667163372039794921875f, _305), _292 = mad(_170, 0.16666667163372039794921875f, _291), _294 = mad(_171, 0.16666667163372039794921875f, _293), _296 = mad(_172, 0.16666667163372039794921875f, _295), _298 = mad(_173, 0.16666667163372039794921875f, _297), _359 = _292 / _298, _360 = _294 / _298, _361 = _296 / _298, _382 = _300 / _306, _383 = _302 / _306, _384 = _382 + 0.5f, _385 = _383 + 0.5f, _393 = mad(T3.SampleCmpLevelZero(S0, float2(_359, _360), _361).xxxx.x, CB0_m0[14u].z, _255) * T2.SampleLevel(S1, float2(_384, _385), CB0_m0[14u].y).w, _289++, _291 = _292, _293 = _294, _295 = _296, _297 = _298, _299 = _300, _301 = _302, _303 = _304, _305 = _306, _307 = mad(_393, mad(_254, T1.SampleLevel(S2, float2(dot(float3(_300, _302, _304), float3(_300, _302, _304)), _266), 0.0f).x, CB0_m0[14u].x), _307))
    {
    }
    precise float _311 = (-0.0f) - _123;
    precise float _312 = _311 + _125;
    precise float _316 = _312 * CB0_m0[14u].w;
    precise float _317 = _307 * _316;
    precise float _318 = _317 * 0.16666667163372039794921875f;
    precise float _319 = _317 * 0.083333335816860198974609375f;
    float _326 = asfloat((0u - uint(int(asuint(_318)) >> int(1u))) + 1597463174u);
    precise float _327 = _326 * _326;
    precise float _328 = (-0.0f) - _319;
    precise float _331 = mad(_328, _327, 1.5f) * _326;
    float _333 = min(max(_63, 0.0f), 0.99999988079071044921875f);
    precise float _335 = _333 * 1.0f;
    precise float _336 = _333 * 255.0f;
    precise float _338 = _333 * 65025.0f;
    float _341 = frac(_336);
    float _342 = frac(_338);
    precise float _343 = (-0.0f) - _341;
    precise float _344 = (-0.0f) - _342;
    SV_Target.y = mad(_343, 0.0039215688593685626983642578125f, frac(_335));
    SV_Target.z = mad(_344, 0.0039215688593685626983642578125f, _341);
    SV_Target.w = mad(_344, 0.0039215688593685626983642578125f, _342);
    precise float _353 = _117.z + _117.y;
    precise float _354 = _353 + (-1.5f);
    precise float _356 = _354 * 0.0039215688593685626983642578125f;
    SV_Target.x = mad(_318, _331, _356);
    discard_exit();
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    gl_FragCoord = stage_input.gl_FragCoord;
    gl_FragCoord.w = 1.0 / gl_FragCoord.w;
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
