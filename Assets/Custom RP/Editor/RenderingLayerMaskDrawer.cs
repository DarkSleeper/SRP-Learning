using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

[CustomPropertyDrawer(typeof(RenderingLayerMaskFieldAttribute))]
public class RenderingLayerMaskDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        Draw(position, property, label);
    }

    public static void Draw(SerializedProperty property, GUIContent label)
    {
        Draw(EditorGUILayout.GetControlRect(), property, label);
    }

    public static void Draw(
        Rect position, SerializedProperty property, GUIContent label
    )
    {
        EditorGUI.showMixedValue = property.hasMultipleDifferentValues;
        EditorGUI.BeginChangeCheck();
        int mask = property.intValue;
        bool isUint = property.type == "uint";
        if (isUint && mask == int.MaxValue) // everything
        {
            mask = -1;
        }
        mask = EditorGUI.MaskField(
            position, label, mask,
            GraphicsSettings.currentRenderPipeline.renderingLayerMaskNames
        );
        if (EditorGUI.EndChangeCheck())
        {
            property.intValue = isUint && mask == -1 ? int.MaxValue : mask;
        }
        EditorGUI.showMixedValue = false;
    }
}