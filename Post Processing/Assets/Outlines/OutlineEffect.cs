using UnityEngine;

using CameraCommon;

[RequireComponent (typeof (Camera))]
[ExecuteInEditMode]
public class OutlineEffect : MonoBehaviour
{
    [Header("Outline")]
    public Color outlineColor = Color.black;
    [Range(0, 10)]
    public int sampleDistance = 1;
    [Range(0.0f, 5.0f)]
    public float depthStrength = 1;
    [Range(0.0f, 5.0f)]
    public float luminanceStrength = 1;
    [Range(0.0f, 5.0f)]
    public float normlaStrength = 1;

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
        Vector3 sampleStrenght = new Vector3 (depthStrength, luminanceStrength, normlaStrength);
        OutlineMaterial.SetVector("_SampleStrenght", sampleStrenght);

        OutlineMaterial.DisableKeyword("EDGE_CHECKER");
        if (enableEdgeChecker) 
        {
            OutlineMaterial.SetColor("_BackgroundColor", backgroundColor);
            OutlineMaterial.EnableKeyword("EDGE_CHECKER");
        }

        Graphics.Blit(_source, _destination, OutlineMaterial);
    }
}
