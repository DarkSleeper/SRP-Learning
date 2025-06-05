using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CustomRenderPipeline : RenderPipeline
{
    bool useDynamicBatching, useGPUInstancing, useLightsPerObject;

    CameraBufferSettings cameraBufferSettings;

    ShadowSettings shadowSettings;

    PostFXSettings postFXSettings;

    int colorLUTResolution;

    public CustomRenderPipeline(
        CameraBufferSettings cameraBufferSettings,
        bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher,
        bool useLightsPerObject, ShadowSettings shadowSettings,
        PostFXSettings postFXSettings, int colorLUTResolution, Shader cameraRendererShader
    )
    {
        this.colorLUTResolution = colorLUTResolution;
        this.cameraBufferSettings = cameraBufferSettings;
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        this.useLightsPerObject = useLightsPerObject;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        this.shadowSettings = shadowSettings;
        this.postFXSettings = postFXSettings;

        InitializeForEditor(); // for point/spot light baking attenuation

        renderer = new CameraRenderer(cameraRendererShader);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        DisposeForEditor();
        renderer.Dispose();
    }

    CameraRenderer renderer;

    protected override void Render(
        ScriptableRenderContext context, Camera[] cameras
    ) { }

    protected override void Render(
        ScriptableRenderContext context, List<Camera> cameras
    ) { 
        for (int i = 0; i < cameras.Count; i++) {
            renderer.Render(
                context, cameras[i], cameraBufferSettings,
                useDynamicBatching, useGPUInstancing, useLightsPerObject,
                shadowSettings, postFXSettings, colorLUTResolution
            );
        }
    }
}
