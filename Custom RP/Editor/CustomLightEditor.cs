using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

[CanEditMultipleObjects] //支持多选
[CustomEditorForRenderPipeline(typeof(Light), typeof(CustomRenderPipelineAsset))]
public class CustomLightEditor : LightEditor
{
    // 替换默认的Inspector
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        RenderingLayerMaskDrawer.Draw(settings.renderingLayerMask, renderingLayerMaskLabel);

        // 检查是否只选择聚光灯
        if (
            !settings.lightType.hasMultipleDifferentValues &&
            (LightType)settings.lightType.enumValueIndex == LightType.Spot
        )
        {
            settings.DrawInnerAndOuterSpotAngle();
        }

        settings.ApplyModifiedProperties();

        var light = target as Light;
        if (light.cullingMask != -1)
        {
            EditorGUILayout.HelpBox(
                light.type == LightType.Directional ?
                    "Culling Mask only affects shadows." :
                    "Culling Mask only affects shadow unless Use Lights Per Objects is on.",
                MessageType.Warning
            );
        }
    }

    static GUIContent renderingLayerMaskLabel =
        new GUIContent("Rendering Layer Mask", "Functional version of above property.");
}
