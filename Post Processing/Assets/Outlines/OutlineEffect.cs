using UnityEngine;
using UnityEngine;

using CameraCommon;

[RequireComponent (typeof (Camera))]
[ExecuteInEditMode]
public class OutlineEffect : MonoBehaviour
{
    [Header("Outline")]
    public Color outlineColor = Color.black;
    [Range(0.01f, 10.0f)]
    public float sampleDistance = 1;

    [Header("Outline Checker")]
    public bool enableEdgeChecker;
    public Color backgroundColor = Color.yellow;

    [HideInInspector]
    public Shader OutlineShader;
    private Material OutlineMaterial;

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(OutlineShader, ref OutlineMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        OutlineMaterial.SetColor("_OutlineColor", outlineColor);
        OutlineMaterial.SetFloat("_SampleDistance", sampleDistance);

        OutlineMaterial.DisableKeyword("EDGE_CHECKER");
        if (enableEdgeChecker) 
        {
            OutlineMaterial.SetColor("_BackgroundColor", backgroundColor);
            OutlineMaterial.EnableKeyword("EDGE_CHECKER");
        }

        Graphics.Blit(_source, _destination, OutlineMaterial);
    }
}
