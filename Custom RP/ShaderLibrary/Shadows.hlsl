#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

// 每个采样点都是2x2的双线性插值，所以间隔采样
#if defined(_DIRECTIONAL_PCF3)
    #define DIRECTIONAL_FILTER_SAMPLES 4
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
    #define DIRECTIONAL_FILTER_SAMPLES 9
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
    #define DIRECTIONAL_FILTER_SAMPLES 16
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
    int _CascadeCount;
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4 _CascadeData[MAX_CASCADE_COUNT];
    float4 _ShadowAtlasSize;
    float4 _ShadowDistanceFade;
CBUFFER_END

struct DirectionalShadowData {
    float strength;
    int tileIndex;
    float normalBias;
    int shadowMaskChannel;
};

// 阴影烘焙
struct ShadowMask {
    bool always; // 模式1
    bool distance; // 模式2
    float4 shadows;
};

// 级联层级是按片元计算的，和光源无关
struct ShadowData {
    int cascadeIndex;
    float cascadeBlend;
    float strength;
    ShadowMask shadowMask;
};

// 采样阴影贴图，并返回阴影程度
float SampleDirectionalShadowAtlas(float3 positionSTS) {
    return SAMPLE_TEXTURE2D_SHADOW(
        _DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
    );
}

// 应用PCF
float FilterDirectionalShadow(float3 positionSTS) {
    #if defined(DIRECTIONAL_FILTER_SETUP)
        float weights[DIRECTIONAL_FILTER_SAMPLES];
        float2 positions[DIRECTIONAL_FILTER_SAMPLES];
        float4 size = _ShadowAtlasSize.yyxx;
        DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
        float shadow = 0;
        for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
            shadow += weights[i] * SampleDirectionalShadowAtlas(
                float3(positions[i], positionSTS.z)
            );
        }
        return shadow;
    #else
        return SampleDirectionalShadowAtlas(positionSTS);
    #endif
}

// 计算实时阴影：变换坐标，采样阴影，根据光源的阴影强度返回结果
float GetCascadedShadow(
    DirectionalShadowData directional, ShadowData global, Surface surfaceWS
) {
    float3 normalBias = surfaceWS.interpolatedNormal * 
        (directional.normalBias * _CascadeData[global.cascadeIndex].y);
    float3 positionSTS = mul(
        _DirectionalShadowMatrices[directional.tileIndex],
        float4(surfaceWS.position + normalBias, 1.0)
    ).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);
    // 两个级联阴影混合
    if (global.cascadeBlend < 1.0) {
        normalBias = surfaceWS.interpolatedNormal * 
            (directional.normalBias * _CascadeData[global.cascadeIndex + 1].y); // 下一层级
        positionSTS = mul(
            _DirectionalShadowMatrices[directional.tileIndex + 1], // 下一层级
            float4(surfaceWS.position + normalBias, 1.0)
        ).xyz;
        shadow = lerp(
            FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend
        );
    }
    return shadow;
}

// 获取烘焙阴影结果
float GetBakedShadow(ShadowMask mask, int channel) {
    float shadow = 1.0;
    if (mask.always || mask.distance) {
        if (channel >= 0) {
            shadow = mask.shadows[channel];
        }
    }
    return shadow;
}

// 仅使用烘焙阴影的情况
float GetBakedShadow(ShadowMask mask, int channel, float strength) {
    if (mask.always || mask.distance) {
        return lerp(1.0, GetBakedShadow(mask, channel), strength);
    }
    return 1.0;
}

// 混合实时阴影和烘焙阴影
float MixBakedAndRealtimeShadows(
    ShadowData global, float shadow, int shadowMaskChannel, float strength
) {
    float baked  = GetBakedShadow(global.shadowMask, shadowMaskChannel);
    if (global.shadowMask.always) { // 使用静态物体的烘焙，与动态物体的阴影取最小
        shadow = lerp(1.0, shadow, global.strength);
        shadow = min(baked, shadow);
        return lerp(1.0, shadow, strength);
    }
    if (global.shadowMask.distance) { // 混合使用
        shadow = lerp(baked, shadow, global.strength);
        return lerp(1.0, shadow, strength);
    }
    return lerp(1.0, shadow, strength * global.strength); // 前者是光源自带的strength属性，后者用于剔除级联阴影范围外的采样
}

// 计算方向光的阴影，混合了实时的和烘焙的
float GetDirectionalShadowAttenuation(
    DirectionalShadowData directional, ShadowData global, Surface surfaceWS
) {
    #if !defined(_RECEIVE_SHADOWS)
        return 1.0;
    #endif

    float shadow;
    if (directional.strength * global.strength <= 0.0) { // 超出实时阴影范围
        shadow = GetBakedShadow(global.shadowMask, directional.shadowMaskChannel, abs(directional.strength));
    }
    else {
        shadow = GetCascadedShadow(directional, global, surfaceWS);
        shadow = MixBakedAndRealtimeShadows(global, shadow, directional.shadowMaskChannel, directional.strength);
    }
    
    return shadow;
}

// 计算阴影超出范围的淡出效果
float FadeShadowStrength(float distance, float scale, float fade) {
    return saturate((1.0 - distance * scale) * fade); // 公式里是除法，但是可以预先将uniform取倒数，在shader里用乘法
}

// 计算级联层级
ShadowData GetShadowData(Surface surfaceWS) {
    ShadowData data;
    data.shadowMask.always = false;
    data.shadowMask.distance = false;
    data.shadowMask.shadows = 1.0;

    data.cascadeBlend = 1.0;
    // 超出阴影距离的淡出
    data.strength = FadeShadowStrength(
        surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y
    );

    int i;
    for (i = 0; i < _CascadeCount; i++) {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
        if (distanceSqr < sphere.w) {
            float fade = FadeShadowStrength(
                distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z
            );
            // 在最高级联层级的阴影淡出
            if (i == _CascadeCount - 1) {
                data.strength *= fade;
            } else {
                data.cascadeBlend = fade;
            }
            break;
        }
    }

    if (i == _CascadeCount) {
        data.strength = 0.0;
    }
#if defined(_CASCADE_BLEND_DITHER)
    else if (data.cascadeBlend < surfaceWS.dither) {
        i += 1;
    }
#endif

    #if !defined(_CASCADE_BLEND_SOFT)
        data.cascadeBlend = 1.0;
    #endif

    data.cascadeIndex = i;
    return data;
}

#endif

