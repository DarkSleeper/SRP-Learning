#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

// cos * L项
float3 IncomingLight(Surface surface, Light light) {
    return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}

// 单个光源的光照计算
float3 GetLighting(Surface surface, BRDF brdf, Light light) {
    return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

// 光照计算的主函数
float3 GetLighting(Surface surfaceWS, BRDF brdf, GI gi) {
    ShadowData shadowData = GetShadowData(surfaceWS);
    shadowData.shadowMask = gi.shadowMask;
    float3 color = IndirectBRDF(surfaceWS, brdf, gi.diffuse, gi.specular); // 全局光照
    for (int i = 0; i < GetDirectionalLightCount(); i++) {
        Light light = GetDirectionalLight(i, surfaceWS, shadowData);
        color += GetLighting(surfaceWS, brdf, light);
    }
    return color;
}

#endif

