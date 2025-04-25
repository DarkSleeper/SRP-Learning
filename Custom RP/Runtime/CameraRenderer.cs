using System.Collections.Generic;
using Unity.VisualScripting.Dependencies.Sqlite;
using UnityEditor.VersionControl;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    ScriptableRenderContext context;

    Camera camera;

    const string bufferName = "Render Camera";

    CommandBuffer buffer = new CommandBuffer {
        name = bufferName
    };

    CullingResults cullingResults;

    public void Render(ScriptableRenderContext context, Camera camera) {
        this.context = context;
        this.camera = camera;

        PrepareBuffer();
        PrepareForSceneWindow();
        if (!Cull()) {
            return;
        }

        Setup();
        DrawVisibleGeometry();
        DrawUnsupportedShaders();
        DrawGizmos();
        Submit();
    }

    bool Cull() {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p)) {
            cullingResults = context.Cull(ref p);
            return true;
        }
        else return false;
    }

    void Setup() {
        context.SetupCameraProperties(camera);
        CameraClearFlags flags = camera.clearFlags;
        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth,
            flags == CameraClearFlags.Color,
            flags == CameraClearFlags.Color ? camera.backgroundColor.linear : Color.clear
        );
        buffer.BeginSample(SampleName);
        ExecuteBuffer();
    }

    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");

    void DrawVisibleGeometry() {
        var sortingSettings = new SortingSettings(camera) {
            criteria = SortingCriteria.CommonOpaque
        }; // 正交排序或按距离排序
        var drawingSettings = new DrawingSettings(
            unlitShaderTagId, sortingSettings
        );
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        context.DrawSkybox(camera);

        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cullingResults,ref drawingSettings, ref filteringSettings);
    }

    void Submit() {
        buffer.EndSample(SampleName);
        ExecuteBuffer();
        context.Submit();
    }

    void ExecuteBuffer() {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
