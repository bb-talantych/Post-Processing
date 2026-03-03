using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(HeightFogEffect))]
public class HeightFogEditor : Editor
{
    SerializedProperty fogColor;
    SerializedProperty fogMode;
    SerializedProperty startPos;
    SerializedProperty endPos;
    SerializedProperty density;

    void OnEnable()
    {
        fogColor = serializedObject.FindProperty("fogColor");
        fogMode = serializedObject.FindProperty("fogMode");
        startPos = serializedObject.FindProperty("startPos");
        endPos = serializedObject.FindProperty("endPos");
        density = serializedObject.FindProperty("density");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.PropertyField(fogColor);
        EditorGUILayout.Space();
        EditorGUILayout.PropertyField(fogMode);
        HeightFogEffect.FogMode mode =
            (HeightFogEffect.FogMode)fogMode.enumValueIndex;

        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(startPos);
        if (mode == HeightFogEffect.FogMode.Linear)
        {
            EditorGUILayout.PropertyField(endPos);
        }
        else
        {
            EditorGUILayout.PropertyField(density);
        }
        EditorGUI.indentLevel--;

        serializedObject.ApplyModifiedProperties();
    }
}
