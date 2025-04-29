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

    public void Setup (
        ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings
    ) {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;

        ShadowedDirectionalLightCount = 0;
    }

    void ExecuteBuffer() {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

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

    static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");

    void RenderDirectionalShadows() {
        int atlasSize = (int)settings.directional.atlasSize;
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

        int split = ShadowedDirectionalLightCount <= 1 ? 1 : 2;
        int tileSize = atlasSize / split;

        for (int i = 0; i < ShadowedDirectionalLightCount; i++) {
            RenderDirectionalShadows(i, split, tileSize);
        }

        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void SetTileViewport(int index, int split, float tileSize) {
        var offset = new Vector2(index % split, index / split);
        buffer.SetViewport(new Rect(
            offset.x * tileSize, offset.y * tileSize, tileSize, tileSize
        ));
    }

    void RenderDirectionalShadows(int index, int split, int tileSize) {
        var light = ShadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(
            cullingResults, light.visibleLightIndex,
            BatchCullingProjectionType.Orthographic // 2022版本要求说明正交投影，2023版本取消该要求
        );
        // 方向光源的ClipSpace只要求朝向正确，并覆盖可见阴影的范围即可
        cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
            light.visibleLightIndex, 0, 1, Vector3.zero, tileSize, 0f,
            out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
            out ShadowSplitData splitData
        );
        shadowSettings.splitData = splitData;
        SetTileViewport(index, split, tileSize);
        buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
        ExecuteBuffer();
        context.DrawShadows(ref shadowSettings);
    }

    public void Cleanup() {
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }


    const int maxShadowedDirectionalLightCount = 4;

    struct ShadowedDirectionalLight {
        public int visibleLightIndex;
    }

    ShadowedDirectionalLight[] ShadowedDirectionalLights = 
        new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    public void ReserveDirectionalShadows(Light light, int visibleLightIndex) {
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount &&
            light.shadows != LightShadows.None && light.shadowStrength > 0 &&
            cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b)
        ) {
            ShadowedDirectionalLights[ShadowedDirectionalLightCount++] = 
                new ShadowedDirectionalLight {
                    visibleLightIndex = visibleLightIndex
                };
        }
    }
}

