cbuffer CB0UBO : register(b0 )
{
    float4 CB0_m0[15] : packoffset(c0);
};

cbuffer CB1UBO : register(b1 )
{
    float4 CB1_m0[8] : packoffset(c0);
};

Texture2D<float4> BlueNoiseTex : register(t0 );
Texture2D<float4> T1 : register(t1 );
Texture2D<float4> T2 : register(t2 );
SamplerState S0 : register(s0 );

static float4 gl_FragCoord;
static float4 SV_Target;

// cb0_v13 26.0818214, 26081.8222656, 0.8128801, 0.0818215
// cb0_v14 256.00, 256.00, 0.0039063, 0.0039063



struct SPIRV_Cross_Input
{
    float4 gl_FragCoord : SV_Position;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

void frag_main()
{
    float4 BlueNoiseTex_Size = CB0_m0[14u];
    precise float _56 = mad(CB0_m0[13u].w, 1259.0f, gl_FragCoord.x) * BlueNoiseTex_Size.z;
    precise float _57 = mad(CB0_m0[13u].w, 1277.0f, gl_FragCoord.y) * BlueNoiseTex_Size.w;
    float2 screenUV = float2(_56, _57);
    float4 blueNoise = BlueNoiseTex.SampleLevel(S0, screenUV, 0.0f);
    float _65 = blueNoise.y;

    SV_Target.xyz = _65.xxx;
    // SV_Target.xyz = float3(gl_FragCoord.xy, 0);
    SV_Target.w = 1;
    return;

    precise float _68 = blueNoise.x * 6.283185482025146484375f;
    precise float _70 = _65 * 0.25f;
    precise float _74 = cos(_68) * 3.099999904632568359375f;
    precise float _76 = sin(_68) * 3.099999904632568359375f;
    float _81 = asfloat(uint(int(asuint(_70)) >> int(1u)) + 532487669u);
    float _94 = asfloat(uint(int(asuint(mad(_65, 0.25f, 0.25f))) >> int(1u)) + 532487669u);
    float _96 = asfloat(uint(int(asuint(mad(_65, 0.25f, 0.5f))) >> int(1u)) + 532487669u);
    precise float _98 = _81 * _74;
    precise float _99 = _81 * _76;
    precise float _100 = (-0.0f) - _76;
    precise float _102 = (-0.0f) - _74;
    precise float _103 = _94 * _100;
    precise float _104 = _94 * _74;
    float4 _117 = T1.Load(int3(uint2(uint(int(mad(gl_FragCoord.x, 0.5f, _98))), uint(int(mad(gl_FragCoord.y, 0.5f, _99)))), 0u));
    float _120 = _117.x;
    float4 _124 = T1.Load(int3(uint2(uint(int(mad(gl_FragCoord.x, 0.5f, _103))), uint(int(mad(gl_FragCoord.y, 0.5f, _104)))), 0u));
    float _126 = _124.x;
    precise float _130 = (-0.0f) - _74;
    precise float _131 = (-0.0f) - _76;
    precise float _132 = _96 * _130;
    precise float _133 = _96 * _131;
    float _134 = asfloat(uint(int(asuint(mad(_65, 0.25f, 0.75f))) >> int(1u)) + 532487669u);
    precise float _135 = _134 * _76;
    precise float _136 = _134 * _102;
    float4 _149 = T1.Load(int3(uint2(uint(int(mad(gl_FragCoord.x, 0.5f, _132))), uint(int(mad(gl_FragCoord.y, 0.5f, _133)))), 0u));
    float _151 = _149.x;
    float4 _155 = T1.Load(int3(uint2(uint(int(mad(gl_FragCoord.x, 0.5f, _135))), uint(int(mad(gl_FragCoord.y, 0.5f, _136)))), 0u));
    float _157 = _155.x;
    float _161 = dot(float3(_117.yzw), float3(1.0f, 0.0039215688593685626983642578125f, 1.5378700481960549950599670410156e-05f));
    float _168 = dot(float3(_124.yzw), float3(1.0f, 0.0039215688593685626983642578125f, 1.5378700481960549950599670410156e-05f));
    float _171 = dot(float3(_149.yzw), float3(1.0f, 0.0039215688593685626983642578125f, 1.5378700481960549950599670410156e-05f));
    float _174 = dot(float3(_155.yzw), float3(1.0f, 0.0039215688593685626983642578125f, 1.5378700481960549950599670410156e-05f));
    precise float _183 = (-0.0f) - min(min(min(_174, _171), _168), _161);
    precise float _184 = _183 + max(max(max(_174, _171), _168), _161);
    precise float _185 = _168 + _161;
    precise float _186 = _171 + _185;
    precise float _187 = _174 + _186;
    precise float _188 = _187 * 0.25f;
    precise float _189 = _184 / _188;
    float _245;
    if (_189 < 0.100000001490116119384765625f)
    {
        precise float _193 = _126 * _126;
        precise float _197 = mad(_157, _157, mad(_151, _151, mad(_120, _120, _193))) * 0.25f;
        _245 = _197;
    }
    else
    {
        precise float _215 = 1.0f / mad(CB1_m0[7u].x, T2.Load(int3(uint2(uint(int(gl_FragCoord.x)), uint(int(gl_FragCoord.y))), 0u)).x, CB1_m0[7u].y);
        precise float _216 = (-0.0f) - _215;
        precise float _217 = _216 + _161;
        precise float _218 = _216 + _168;
        precise float _219 = _216 + _171;
        precise float _220 = _216 + _174;
        precise float _225 = abs(_217) + 9.9999997473787516355514526367188e-06f;
        precise float _227 = abs(_218) + 9.9999997473787516355514526367188e-06f;
        precise float _228 = abs(_219) + 9.9999997473787516355514526367188e-06f;
        precise float _229 = abs(_220) + 9.9999997473787516355514526367188e-06f;
        precise float _230 = 1.0f / _225;
        precise float _231 = 1.0f / _227;
        precise float _232 = 1.0f / _228;
        precise float _233 = 1.0f / _229;
        precise float _234 = _231 + _230;
        precise float _235 = _232 + _234;
        precise float _236 = _233 + _235;
        precise float _237 = _120 * _120;
        precise float _238 = _126 * _126;
        precise float _239 = _151 * _151;
        precise float _240 = _157 * _157;
        precise float _244 = dot(float4(_230, _231, _232, _233), float4(_237, _238, _239, _240)) / _236;
        _245 = _244;
    }
    precise float _246 = _65 * 0.0039215688593685626983642578125f;
    precise float _247 = blueNoise.z * 0.0039215688593685626983642578125f;
    precise float _248 = blueNoise.w * 0.0039215688593685626983642578125f;
    precise float _255 = (-0.0f) - _246;
    precise float _256 = (-0.0f) - _247;
    precise float _257 = (-0.0f) - _248;
    SV_Target.x = mad(_245, CB0_m0[12u].x, _255);
    SV_Target.y = mad(_245, CB0_m0[12u].y, _256);
    SV_Target.z = mad(_245, CB0_m0[12u].z, _257);
    SV_Target.w = 1.0f;
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
