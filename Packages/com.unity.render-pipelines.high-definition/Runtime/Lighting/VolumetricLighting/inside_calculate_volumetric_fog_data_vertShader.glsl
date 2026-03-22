// ---- Created with 3Dmigoto v1.3.16 on Sat Mar 21 19:17:04 2026
cbuffer cb0 : register(b0)
{
  float4 cb0[38];
}

// cb0_v0 0.00, 0.00, 0.00, 0.00                             0 float4
// cb0_v1 0.00, 0.00, 0.00, 0.00                             16 float4
// cb0_v2 0.00, 0.00, 0.00, 0.00                             32 float4
// cb0_v3 0.00, 0.00, 0.00, 0.00                             48 float4
// cb0_v4 0.00, 0.00, 0.00, 0.00                             64 float4
// cb0_v5 0.00, 0.00, 0.00, 0.00                             80 float4
// cb0_v6 0.4684232, 0.0017307, -0.793774, -0.762023         96 float4
// cb0_v7 0.1466907, -1.4882758, -0.2113314, -0.2028781      112 float4
// cb0_v8 -1.4419253, -0.3242235, -0.6405724, -0.6149495     128 float4
// cb0_v9 292.8057251, -248.0874023, -485.2383728, -465.408844 144 float4
// cb0_v10 0.00, 0.00, 0.00, 0.00                             160 float4
// cb0_v11 0.00, 0.00, 0.00, 0.00                             176 float4
// cb0_v12 0.00, 0.00, 0.00, 0.00                             192 float4
// cb0_v13 0.00, 0.00, 0.00, 0.00                             208 float4
// cb0_v14 0.00, 6.00, 1.00, 0.01                             224 float4
// cb0_v15 26.0818214, 26081.8222656, 0.8128801, 0.0818215    240 float4
// cb0_v16 256.00, 256.00, 0.0039063, 0.0039063               256 float4
// cb0_v17 5.7987328, -2.3270152, -6.5375466, -6.5266509      272 float4
// cb0_v18 9.2269077, -5.3138218, 6.3324738, 6.3219199        288 float4
// cb0_v19 2.6843946, 16.6407356, 0.3654782, 0.3648691        304 float4
// cb0_v20 -4.9527025, 4.882935, 6.5773978, 7.5664358         320 float4
// cb0_v21 4.9156747, 1.1096137, 6.5266509, 0.00              336 float4
// cb0_v22 7.8217912, 2.5338421, -6.3219199, 0.00             352 float4
// cb0_v23 2.2756026, -7.9349666, -0.3648691, 0.00            368 float4
// cb0_v24 -4.198482, -2.3283782, -7.5664358, 1.00            384 float4
// cb0_v25 0.00, 0.00, 0.00, 0.00                             400 float4
// cb0_v26 0.00, 0.00, 0.00, 0.00                             416 float4
// cb0_v27 0.00, 0.00, 0.00, 0.00                             432 float4
// cb0_v28 0.00, 0.00, 0.00, 0.00                             448 float4
// cb0_v29 0.00, 0.00, 0.00, 0.00                             464 float4
// cb0_v30 0.0567817, 0.0262313, -0.0718324, -0.049926        480 float4
// cb0_v31 0.0128173, -0.0914678, -0.0232699, -0.0161733      496 float4
// cb0_v32 -0.0753903, 0.0042059, -0.0580581, -0.0403524      512 float4
// cb0_v33 0.8386726, -0.1346678, 0.6054637, 0.4208187        528 float4
// cb0_v34 0.9999085, -0.009644, -0.0094843, 0.00             544 float4
// cb0_v35 0.0101543, 0.9984175, 0.0553121, 0.00              560 float4
// cb0_v36 0.0089359, -0.0554033, 0.9984241, 0.00             576 float4
// cb0_v37 -567.4663696, -166.1251221, -9.1715784, 1.00       592 float4




// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : POSITION0,
  float3 v1 : NORMAL0,
  float4 v2 : TEXCOORD0,
  out float4 o0 : SV_POSITION0,
  out float4 o1 : TEXCOORD0,
  out float4 o2 : TEXCOORD1,
  out float4 o3 : TEXCOORD2,
  out float4 o4 : TEXCOORD3,
  out float4 o5 : TEXCOORD4)
{
  float4 r0,r1,r2;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = cb0[18].xyzw * v0.yyyy;
  r0.xyzw = cb0[17].xyzw * v0.xxxx + r0.xyzw;
  r0.xyzw = cb0[19].xyzw * v0.zzzz + r0.xyzw;
  o0.xyzw = cb0[20].xyzw * v0.wwww + r0.xyzw;

  r0.xyz = cb0[22].xyz * v0.yyy;
  r0.xyz = cb0[21].xyz * v0.xxx + r0.xyz;
  r0.xyz = cb0[23].xyz * v0.zzz + r0.xyz;
  r0.xyz = cb0[24].xyz * v0.www + r0.xyz;

  o1.x = -r0.z;
  r0.xy = -r0.xy / r0.zz;
  r1.xyz = cb0[35].xyz * r0.yyy;
  r1.xyz = cb0[34].xyz * r0.xxx + r1.xyz;
  r1.xyz = cb0[36].xyz + r1.xyz;

  r2.xyzw = cb0[7].xyzw * r1.yyyy;
  r2.xyzw = cb0[6].xyzw * r1.xxxx + r2.xyzw;
  r1.xyzw = cb0[8].xyzw * r1.zzzz + r2.xyzw;

  o2.xyzw = r1.xyzw * r0.zzzz;

  r1.xyzw = cb0[37].yyyy * cb0[7].xyzw;
  r1.xyzw = cb0[6].xyzw * cb0[37].xxxx + r1.xyzw;
  r1.xyzw = cb0[8].xyzw * cb0[37].zzzz + r1.xyzw;
  o3.xyzw = cb0[9].xyzw * cb0[37].wwww + r1.xyzw;

  r1.xyzw = cb0[31].xyzw * r0.yyyy;
  r1.xyzw = cb0[30].xyzw * r0.xxxx + r1.xyzw;
  r1.xyzw = cb0[32].xyzw + r1.xyzw;
  
  o4.xyzw = r1.xyzw * r0.zzzz;
  o5.xyzw = cb0[33].xyzw;

  o1.yz = 0.0;
  o1.w = 1;
  return;
}