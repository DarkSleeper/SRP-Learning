using System.Collections.Generic;
using Unity.VisualScripting.Dependencies.Sqlite;
using UnityEditor.VersionControl;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Profiling;

partial class CameraRenderer
{
    partial void PrepareBuffer();

    partial void DrawGizmosBeforeFX();

    partial void DrawGizmosAfterFX();

    partial void DrawUnsupportedShaders();

    partial void PrepareForSceneWindow();

#if UNITY_EDITOR

    string SampleName { get; set; }

    partial void PrepareBuffer() {
        // 用于检测内存分配（GC Alloc）
        Profiler.BeginSample("Editor Only");
        buffer.name = SampleName = camera.name;
        Profiler.EndSample();
    }

    static ShaderTagId[] legacyShaderTagIds = {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };

    static Material errorMaterial;

    partial void DrawGizmosBeforeFX()
    {
        if (Handles.ShouldRenderGizmos()) {
            context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
        }
    }
    
    partial void DrawGizmosAfterFX()
    {
        if (Handles.ShouldRenderGizmos()) {
            context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
        }
    }

    partial void DrawUnsupportedShaders()
    {
        if (errorMaterial == null)
        {
            errorMaterial = new Material(Shader.Find("Hidden/InternalErrorShader"));
        }
        var drawingSettings = new DrawingSettings(
            legacyShaderTagIds[0], new SortingSettings(camera)
        )
        {
            overrideMaterial = errorMaterial
        };
        for (int i = 1; i < legacyShaderTagIds.Length; i++)
        {
            drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
        }
        var filteringSettings = FilteringSettings.defaultValue;
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    partial void PrepareForSceneWindow() {
        if (camera.cameraType == CameraType.SceneView) {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
        }
    }

#else
    
    const string SampleName = bufferName; // 在release版本里节省空间

#endif
}
