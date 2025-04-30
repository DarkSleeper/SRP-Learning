#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
    int _CascadeCount;
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
    float4 _ShadowDistanceFade;
CBUFFER_END

struct DirectionalShadowData {
    float strength;
    int tileIndex;
};

// 采样阴影贴图，并返回阴影程度
float SampleDirectionalShadowAtlas(float3 positionSTS) {
    return SAMPLE_TEXTURE2D_SHADOW(
        _DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
    );
}

// 变换坐标，采样阴影，根据光源的阴影强度返回结果
float GetDirectionalShadowAttenuation(DirectionalShadowData data, Surface surfaceWS) {
    if (data.strength <= 0.0) {
        return 1.0;
    }
    float3 positionSTS = mul(
        _DirectionalShadowMatrices[data.tileIndex],
        float4(surfaceWS.position, 1.0)
    ).xyz;
    float shadow = SampleDirectionalShadowAtlas(positionSTS);
    return lerp(1.0, shadow, data.strength);
}

// 级联层级是按片元计算的，和光源无关
struct ShadowData {
    int cascadeIndex;
    float strength;
};

// 计算阴影超出范围的淡出效果
float FadeShadowStrength(float distance, float scale, float fade) {
    return saturate((1.0 - distance * scale) * fade); // 公式里是除法，但是可以预先将uniform取倒数，在shader里用乘法
}

// 计算级联层级
ShadowData GetShadowData(Surface surfaceWS) {
    ShadowData data;
    // 超出阴影距离的淡出
    data.strength = FadeShadowStrength(
        surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y
    );

    int i;
    for (i = 0; i < _CascadeCount; i++) {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
        if (distanceSqr < sphere.w) {
            // 在最高级联层级的阴影淡出
            if (i == _CascadeCount - 1) {
                data.strength *= FadeShadowStrength(
                    distanceSqr, 1.0 / sphere.w, _ShadowDistanceFade.z
                );
            }
            break;
        }
    }

    if (i == _CascadeCount) {
        data.strength = 0.0;
    }

    data.cascadeIndex = i;
    return data;
}

#endif

