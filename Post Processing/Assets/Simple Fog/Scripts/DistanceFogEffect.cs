using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class DistanceFogEffect : MonoBehaviour
{
    public Color fogColor = new Color(0.1509434f, 0.1509434f, 0.1509434f, 1);
    public enum FogMode
    {
        Linear,
        Exponential,
        ExponentialSquared
    }
    public FogMode fogMode = FogMode.ExponentialSquared;

    public float startPos = 5f;
    [Min(0f)]
    public float endPos = 15f;
    [Range(0.01f, 2f)]
    public float density = 0.1f;

    [SerializeField, HideInInspector]
    protected Shader fogShader;
    protected Material fogMaterial = null;
    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if (!BB_Rendering.ShaderMaterialReady(fogShader, ref fogMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        fogMaterial.SetColor("_FogColor", fogColor);

        fogMaterial.BB_SetShaderKeyword("ExponentialFactor", false);
        fogMaterial.BB_SetShaderKeyword("ExponentialSquaredFactor", false);
        if (fogMode == FogMode.Exponential)
        {
            fogMaterial.BB_SetShaderKeyword("ExponentialFactor", true);
        }
        else if (fogMode == FogMode.ExponentialSquared)
        {
            fogMaterial.BB_SetShaderKeyword("ExponentialSquaredFactor", true);
        }

        fogMaterial.SetFloat("_StartPos", startPos);
        fogMaterial.SetFloat("_EndPos", endPos);
        fogMaterial.SetFloat("_Density", density);

        Graphics.Blit(_source, _destination, fogMaterial);
    }
}
