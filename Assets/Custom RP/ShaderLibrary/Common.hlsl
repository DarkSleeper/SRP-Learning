#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "UnityInput.hlsl"

// float3 TransformObjectToWorld(float3 positionOS) {
//     return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
// }

// float4 TransformWorldToHClip(float3 positionWS) {
//     return mul(unity_MatrixVP, float4(positionWS, 1.0));
// }

#define UNITY_MATRIX_M          unity_ObjectToWorld
#define UNITY_MATRIX_I_M        unity_WorldToObject
#define UNITY_MATRIX_V          unity_MatrixV
#define UNITY_MATRIX_I_V        unity_MatrixInvV
#define UNITY_MATRIX_VP         unity_MatrixVP
#define UNITY_PREV_MATRIX_M     unity_prev_Matrix_M
#define UNITY_PREV_MATRIX_I_M   unity_prev_Matrix_IM
#define UNITY_MATRIX_P          glstate_matrix_projection

// 为GPU instancing启用occlusion probe
#if defined(_SHADOW_MASK_ALWAYS) || defined(_SHADOW_MASK_DISTANCE)
    #define SHADOWS_SHADOWMASK
#endif

// 引入GPU instancing和空间变换的辅助函数和宏定义
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

SAMPLER(sampler_linear_clamp);
SAMPLER(sampler_point_clamp);

bool IsOrthographicCamera() {
    return unity_OrthoParams.w;
}

float OrthographicDepthBufferToLinear(float rawDepth) {
    #if UNITY_REVERSED_Z
        rawDepth = 1.0 - rawDepth;
    #endif
    return (_ProjectionParams.z - _ProjectionParams.y) * rawDepth + _ProjectionParams.y;
}

#include "Fragment.hlsl"

float Square(float v) {
    return v * v;
}

float DistanceSquared(float3 pA, float3 pB) {
    return dot(pA - pB, pA - pB);
}

// LOD的淡化操作，通过clip实现网格噪声
void ClipLOD(Fragment fragment, float fade) {
    #if defined(LOD_FADE_CROSSFADE)
        float dither = InterleavedGradientNoise(fragment.positionSS, 0); // 每一定数量的像素进行一次渐变，产生交替条纹
        clip(fade + (fade < 0 ? dither : -dither));
    #endif
}

// 解压缩法线贴图
float3 DecodeNormal(float4 sample, float scale) {
    #if defined(UNITY_NO_DXT5nm)
        return normalize(UnpackNormalRGB(sample, scale));
    #else
        return normalize(UnpackNormalmapRGorAG(sample, scale));
    #endif
}

// 法线从切线空间变换到世界空间
float3 NormalTangentToWorld(float3 normalTS, float3 normalWS, float4 tangentWS) {
    float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
    return TransformTangentToWorld(normalTS, tangentToWorld);
}

#endif

