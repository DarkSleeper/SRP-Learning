#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

bool RenderingLayersOverlap(Surface surface, Light light) {
    return (surface.renderingLayerMask & light.renderingLayerMask) != 0;
}

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
        if (RenderingLayersOverlap(surfaceWS, light)) {
            color += GetLighting(surfaceWS, brdf, light);
        }
    }
    #if defined(_LIGHTS_PER_OBJECT)
        for (int j = 0; j < min(unity_LightData.y, 8); j++) {
            int lightIndex = unity_LightIndices[(uint)j / 4][(uint)j % 4];
            Light light = GetOtherLight(lightIndex, surfaceWS, shadowData);
            if (RenderingLayersOverlap(surfaceWS, light)) {
                color += GetLighting(surfaceWS, brdf, light);
            }
        }
    #else
        for (int j = 0; j < GetOtherLightCount(); j++) {
            Light light = GetOtherLight(j, surfaceWS, shadowData);
            if (RenderingLayersOverlap(surfaceWS, light)) {
                color += GetLighting(surfaceWS, brdf, light);
            }
        }
    #endif
    return color;
}

#endif

