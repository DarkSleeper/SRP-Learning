using UnityEngine;

[System.Serializable]
public struct CameraBufferSettings
{
    public bool allowHDR;

    public bool copyColor, copyColorReflection, copyDepth, copyDepthReflection;

    [Range(CameraRenderer.renderScaleMin, CameraRenderer.renderScaleMax)]
    public float renderScale;

    public enum BicubicRescalingMode { Off, UpOnly, UpAndDown }

    public BicubicRescalingMode bicubicRescaling;
}
