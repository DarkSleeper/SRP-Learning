// 避免重定义
#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 baseUV : TEXCOORD0;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float3 normalWS : VAR_NORMAL;
    #if defined(_NORMAL_MAP)
        float4 tangentWS : VAR_TANGENT;
    #endif
    float2 baseUV : VAR_BASE_UV;
    float2 detailUV : VAR_DETAIL_UV;
    GI_VARYINGS_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input) {
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    TRANSFER_GI_DATA(input, output);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    #if defined(_NORMAL_MAP)
        output.tangentWS = float4(
            TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w
        );
    #endif
    output.baseUV = TransformBaseUV(input.baseUV);
    #if defined(_DETAIL_MAP)
        output.detailUV = TransformDetailUV(input.baseUV);
    #endif
    return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(input);
    ClipLOD(input.positionCS.xy, unity_LODFade.x); // LOD切换动画

    InputConfig config = GetInputConfig(input.baseUV);
    #if defined(_MASK_MAP)
        config.useMask = true;
    #endif
    #if defined(_DETAIL_MAP)
        config.detailUV = input.detailUV;
        config.useDetail = true;
    #endif

    // Albedo
    float4 base = GetBase(config);
    #if defined(_CLIPPING)
        clip(base.a - GetCutOff(config));
    #endif

    // 设置表面属性
    Surface surface;
    surface.position = input.positionWS;
    #if defined(_NORMAL_MAP)
        surface.normal = NormalTangentToWorld(
            GetNormalTS(config), input.normalWS, input.tangentWS
        );
        surface.interpolatedNormal = input.normalWS; // 这里可以不normalize，因为只是用于bias，不需要严格归一化
    #else
        surface.normal = normalize(input.normalWS);
        surface.interpolatedNormal = surface.normal;
    #endif
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = GetMetallic(config);
    surface.occlusion = GetOcclusion(config);
    surface.smoothness = GetSmoothness(config);
    surface.fresnelStrength = GetFresnel(config);
    surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
    
    // 获取材质的brdf属性
    #if defined(_PREMULTIPLY_ALPHA)
        BRDF brdf = GetBRDF(surface, true);
    #else
        BRDF brdf = GetBRDF(surface);
    #endif
    // 计算光照结果
    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
    float3 color = GetLighting(surface, brdf, gi);
    color += GetEmission(config);
    return float4(color, GetFinalAlpha(surface.alpha));
}

#endif

