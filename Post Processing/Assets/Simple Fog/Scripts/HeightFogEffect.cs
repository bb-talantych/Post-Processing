using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class HeightFogEffect : MonoBehaviour
{
    public Color fogColor = new Color(0.1509434f, 0.1509434f, 0.1509434f, 1);
    public enum FogMode
    {
        Linear,
        Exponential,
        ExponentialSquared
    }
    public FogMode fogMode = FogMode.ExponentialSquared;

    public float startPos = 1f;
    public float endPos = -1f;
    [Range(0.01f, 2f)]
    public float density = 0.5f;

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

        float halfFOVTan = Mathf.Tan(Camera.main.fieldOfView * 0.5f * Mathf.Deg2Rad);
        fogMaterial.SetFloat("_Half_FOV_Tan", halfFOVTan);
        fogMaterial.SetFloat("_StartPos", startPos);
        fogMaterial.SetFloat("_EndPos", endPos);
        fogMaterial.SetFloat("_Density", density);

        Graphics.Blit(_source, _destination, fogMaterial);
    }
}
