using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CustomRenderPipeline : RenderPipeline
{
    bool useDynamicBatching, useGPUInstancing, useLightsPerObject;

    bool allowHDR;

    ShadowSettings shadowSettings;

    PostFXSettings postFXSettings;

    int colorLUTResolution;

    public CustomRenderPipeline(
        bool allowHDR,
        bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher,
        bool useLightsPerObject, ShadowSettings shadowSettings,
        PostFXSettings postFXSettings, int colorLUTResolution
    )
    {
        this.colorLUTResolution = colorLUTResolution;
        this.allowHDR = allowHDR;
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        this.useLightsPerObject = useLightsPerObject;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        this.shadowSettings = shadowSettings;
        this.postFXSettings = postFXSettings;

        InitializeForEditor(); // for point/spot light baking attenuation
    }

    CameraRenderer renderer = new CameraRenderer();

    protected override void Render(
        ScriptableRenderContext context, Camera[] cameras
    ) { }

    protected override void Render(
        ScriptableRenderContext context, List<Camera> cameras
    ) { 
        for (int i = 0; i < cameras.Count; i++) {
            renderer.Render(
                context, cameras[i], allowHDR,
                useDynamicBatching, useGPUInstancing, useLightsPerObject,
                shadowSettings, postFXSettings, colorLUTResolution
            );
        }
    }
}
