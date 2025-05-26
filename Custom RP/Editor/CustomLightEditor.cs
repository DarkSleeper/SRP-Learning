using UnityEngine;
using UnityEditor;

[CanEditMultipleObjects] //支持多选
[CustomEditorForRenderPipeline(typeof(Light), typeof(CustomRenderPipelineAsset))]
public class CustomLightEditor : LightEditor
{
    // 替换默认的Inspector
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        // 检查是否只选择聚光灯
        if (
            !settings.lightType.hasMultipleDifferentValues &&
            (LightType)settings.lightType.enumValueIndex == LightType.Spot
        )
        {
            settings.DrawInnerAndOuterSpotAngle();
            settings.ApplyModifiedProperties();
        }
    }
}
