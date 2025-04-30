using UnityEngine;
using UnityEngine.Rendering;

public class Shadows {
    const string bufferName = "Shadows";
    CommandBuffer buffer = new CommandBuffer {
        name = bufferName
    };

    ScriptableRenderContext context;

    CullingResults cullingResults;

    ShadowSettings settings;

    int ShadowedDirectionalLightCount;

    // 设置辅助变量
    public void Setup (
        ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings
    ) {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;

        ShadowedDirectionalLightCount = 0;
    }

    // 执行命令并清空缓存
    void ExecuteBuffer() {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    // 绘制阴影贴图的主函数
    public void Render() {
        if (ShadowedDirectionalLightCount > 0) {
            RenderDirectionalShadows();
        }
        else {
            buffer.GetTemporaryRT(
                dirShadowAtlasId, 1, 1,
                32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
            );
        }
    }

    const int maxShadowedDirectionalLightCount = 4, maxCascades = 4;

    static int
        dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
        dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),
        cascadeCountId = Shader.PropertyToID("_CascadeCount"),
        cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
        shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    static Matrix4x4[]
        dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];

    static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];

    // 绘制方向光阴影贴图的主函数
    void RenderDirectionalShadows() {
        int atlasSize = (int)settings.directional.atlasSize;
        // 向GPU申请贴图
        buffer.GetTemporaryRT(
            dirShadowAtlasId, atlasSize, atlasSize,
            32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
        );
        // 将阴影绘制到该贴图上
        buffer.SetRenderTarget(
            dirShadowAtlasId,
            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
        );
        buffer.ClearRenderTarget(true, false, Color.clear);
        buffer.BeginSample(bufferName);
        ExecuteBuffer();

        int tiles = ShadowedDirectionalLightCount * settings.directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;

        // 为每个方向光绘制阴影贴图
        for (int i = 0; i < ShadowedDirectionalLightCount; i++) {
            RenderDirectionalShadows(i, split, tileSize);
        }

        // 设置hlsl需要用到的阴影参数
        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount);
        buffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        float f = 1f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(
            shadowDistanceFadeId, 
            new Vector4(
                1f / settings.maxDistance, 1f / settings.distanceFade,
                1f / (1f - f * f)
            )
        );
        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    // 设置绘制的Viewport，因为阴影贴图是画在一个大的贴图里的
    Vector2 SetTileViewport(int index, int split, float tileSize) {
        var offset = new Vector2(index % split, index / split);
        buffer.SetViewport(new Rect(
            offset.x * tileSize, offset.y * tileSize, tileSize, tileSize
        ));
        return offset;
    }

    // 变换矩阵，以将坐标映射到屏幕空间的对应小贴图上
    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split) {
        // 先把reverse z的处理消除
        if (SystemInfo.usesReversedZBuffer) {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        // 从裁剪空间变换到带有Viewport变化的屏幕空间
        float scale = 1f / split;
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        return m;
    }

    // 绘制单个方向光的阴影贴图
    void RenderDirectionalShadows(int index, int split, int tileSize) {
        var light = ShadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(
            cullingResults, light.visibleLightIndex,
            BatchCullingProjectionType.Orthographic // 2022版本要求说明正交投影，2023版本取消该要求
        );
        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.cascadeRatio;

        for (int i = 0; i < cascadeCount; i++) {
            // 方向光源的ClipSpace只要求朝向正确，并覆盖可见阴影的范围即可
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize, 0f,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            shadowSettings.splitData = splitData;
            if (index == 0) {
                var cullingSphere = splitData.cullingSphere;
                cullingSphere.w *= cullingSphere.w; // 存储平方半径
                cascadeCullingSpheres[i] = cullingSphere;
            }
            // 设置Viewport，并计算从世界坐标到屏幕空间坐标的变换矩阵
            int tileIndex = tileOffset + i;
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(
                projectionMatrix * viewMatrix, 
                SetTileViewport(tileIndex, split, tileSize), split
            );
            // 设置相机参数并绘制阴影贴图
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);
        }
    }

    // 申请的阴影贴图需要清除
    public void Cleanup() {
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }

    struct ShadowedDirectionalLight {
        public int visibleLightIndex;
    }

    ShadowedDirectionalLight[] ShadowedDirectionalLights = 
        new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    // 记录阴影的Index对应的光源Index，并返回阴影强度，以及该光源的阴影贴图在大贴图中的起始位置
    public Vector2 ReserveDirectionalShadows(Light light, int visibleLightIndex) {
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount &&
            light.shadows != LightShadows.None && light.shadowStrength > 0 &&
            cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b)
        ) {
            ShadowedDirectionalLights[ShadowedDirectionalLightCount] = 
                new ShadowedDirectionalLight {
                    visibleLightIndex = visibleLightIndex
                };
            return new Vector2(
                light.shadowStrength,
                settings.directional.cascadeCount * ShadowedDirectionalLightCount++
            );
        }
        return Vector2.zero;
    }
}

