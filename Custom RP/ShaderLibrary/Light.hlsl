#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_OTHER_LIGHT_COUNT 64

CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
    
    int _OtherLightCount;
    float4 _OtherLightColors[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightPositions[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightDirections[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightSpotAngles[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightShadowData[MAX_OTHER_LIGHT_COUNT];
CBUFFER_END

struct Light {
    float3 color;
    float3 direction;
    float attenuation;
};

// 方向光数量
int GetDirectionalLightCount() {
    return _DirectionalLightCount;
}

// 其他光数量
int GetOtherLightCount() {
    return _OtherLightCount;
}

// 获取该方向光的阴影强度和在阴影贴图中的小贴图索引
DirectionalShadowData GetDirectionalShadowData(
    int lightIndex, ShadowData shadowData
) {
    DirectionalShadowData data;
    data.strength = _DirectionalLightShadowData[lightIndex].x;
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
    return data;
}

// 获取其他光源的阴影遮罩信息
OtherShadowData GetOtherShadowData(int lightIndex) {
    OtherShadowData data;
    data.strength = _OtherLightShadowData[lightIndex].x;
    data.tileIndex = _OtherLightShadowData[lightIndex].y;
    data.shadowMaskChannel = _OtherLightShadowData[lightIndex].w;
    data.lightPositionWS = 0.0;
    data.spotDirectionWS = 0.0;
    return data;
}

// 获取方向光光源信息，并计算阴影衰减
Light GetDirectionalLight(int index, Surface surfaceWS, ShadowData shadowData) {
    Light light;
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);
    light.attenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surfaceWS);
    return light;
}

// 获取其他光源信息
Light GetOtherLight(int index, Surface surfaceWS, ShadowData shadowData) {
    Light light;
    light.color = _OtherLightColors[index].rgb;
    // 平方衰减
    float3 position = _OtherLightPositions[index].xyz;
    float3 ray = position - surfaceWS.position;
    light.direction = normalize(ray);
    float distanceSqr = max(dot(ray, ray), 0.00001); 
    float rangeAttenuation = Square(
        saturate(1.0 - Square(distanceSqr * _OtherLightPositions[index].w))
    ); // 限制光照半径
    // 聚光灯实现方法
    float3 spotDirection = _OtherLightDirections[index].xyz;
    float4 spotAngles = _OtherLightSpotAngles[index];
    float spotAttenuation = Square(
        saturate(dot(spotDirection, light.direction) *
        spotAngles.x + spotAngles.y)
    );
    OtherShadowData otherShadowData = GetOtherShadowData(index); // 用于shadow Mask
    otherShadowData.lightPositionWS = position;
    otherShadowData.spotDirectionWS = spotDirection;
    light.attenuation = 
        GetOtherShadowAttenuation(otherShadowData, shadowData, surfaceWS) *
        spotAttenuation * rangeAttenuation / distanceSqr;
    return light;
}
#endif

