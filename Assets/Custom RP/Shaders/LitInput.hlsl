#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

TEXTURE2D(_BaseMap);
TEXTURE2D(_MaskMap);
TEXTURE2D(_EmissionMap);
TEXTURE2D(_NormalMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_DetailMap);
TEXTURE2D(_DetailNormalMap);
SAMPLER(sampler_DetailMap);

// 用GPU Instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _ZWrite)
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

struct InputConfig {
    Fragment fragment;
    float2 baseUV;
    float2 detailUV;
    bool useMask;
    bool useDetail;
};

InputConfig GetInputConfig(float4 positionSS, float2 baseUV, float2 detailUV = 0.0) {
    InputConfig c;
    c.fragment = GetFragment(positionSS);
    c.baseUV = baseUV;
    c.detailUV = detailUV;
    c.useMask = false;
    c.useDetail = false;
    return c;
}

float GetFinalAlpha(float alpha) {
    return INPUT_PROP(_ZWrite) ? 1.0 : alpha;
}

// 基础UV
float2 TransformBaseUV(float2 baseUV) {
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

// 细节贴图的独立UV
float2 TransformDetailUV(float2 detailUV) {
    float4 detailST = INPUT_PROP(_DetailMap_ST);
    return detailUV * detailST.xy + detailST.zw;
}

// Mask Map
float4 GetMask(InputConfig c) {
    if (c.useMask) {
        return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, c.baseUV);
    }
    return 1.0;
}

// Detail Map
float4 GetDetail(InputConfig c) {
    if (c.useDetail) {
        float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, c.detailUV);
        return map * 2.0 - 1.0;
    }
    return 0.0;
}

// Albedo
float4 GetBase(InputConfig c) {
    float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
    float4 color = INPUT_PROP(_BaseColor);

    if (c.useDetail) {
        float detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
        float mask = GetMask(c).b;
        map.rgb = lerp(sqrt(map.rgb), detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask); // 在gamma空间进行颜色插值
        map.rgb *= map.rgb;
    }

    return map * color;
}

// Emmision
float3 GetEmission(InputConfig c) {
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, c.baseUV);
    float4 color = INPUT_PROP(_EmissionColor);
    return map.rgb * color.rgb;
}

// 截断alpha的属性
float GetCutOff(InputConfig c) {
    return INPUT_PROP(_Cutoff);
}

// 金属度
float GetMetallic(InputConfig c) {
    float metallic = INPUT_PROP(_Metallic);
    metallic *= GetMask(c).r;
    return metallic;
}

// 影响间接光照强度
float GetOcclusion(InputConfig c) {
    float strength = INPUT_PROP(_Occlusion);
    float occlusion = GetMask(c).g;
    occlusion = lerp(occlusion, 1.0, strength);
    return occlusion;
}

// 平滑度
float GetSmoothness(InputConfig c) {
    float smoothness = INPUT_PROP(_Smoothness);
    smoothness *= GetMask(c).a;

    if (c.useDetail) {
        float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
        float mask = GetMask(c).b;
        smoothness = lerp(smoothness, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
    }

    return smoothness;
}

// 菲涅尔效应强度
float GetFresnel(InputConfig c) {
    return INPUT_PROP(_Fresnel);
}

// Normal
float3 GetNormalTS(InputConfig c) {
    float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, c.baseUV);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = DecodeNormal(map, scale);

    if (c.useDetail) {
        map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, c.detailUV);
        scale = INPUT_PROP(_DetailNormalScale) * GetMask(c).b;
        float3 detail = DecodeNormal(map, scale);
        normal = BlendNormalRNM(normal, detail);
    }
    
    return normal;
}

#endif

