using UnityEngine;
using UnityEngine.Rendering;

public partial class PostFXStack
{
    enum Pass
    {
        Copy
    }

    const string bufferName = "Post FX";

    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    ScriptableRenderContext context;

    Camera camera;

    PostFXSettings settings;

    public void Setup(
        ScriptableRenderContext context, Camera camera, PostFXSettings settings
    )
    {
        this.context = context;
        this.camera = camera;
        this.settings = camera.cameraType <= CameraType.SceneView ? settings : null;

        ApplySceneViewState();
    }

    // 无后处理配置时，跳过后处理
    public bool IsActive => settings != null;

    public void Render(int sourceId)
    {
        Draw(sourceId, BuiltinRenderTextureType.CameraTarget, Pass.Copy); // simply copy
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    int fxSourceId = Shader.PropertyToID("_PostFXSource");

    void Draw(
        RenderTargetIdentifier from, RenderTargetIdentifier to, Pass pass
    )
    {
        buffer.SetGlobalTexture(fxSourceId, from);
        buffer.SetRenderTarget(
            to, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
        );
        buffer.DrawProcedural(
            Matrix4x4.identity, settings.Material, (int)pass,
            MeshTopology.Triangles, 3
        );
    }
}