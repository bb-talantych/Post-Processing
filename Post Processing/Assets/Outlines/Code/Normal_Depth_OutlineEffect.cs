using UnityEngine;

using CameraCommon;

[RequireComponent (typeof (Camera))]
[ExecuteInEditMode]
public class Normal_Depth_OutlineEffect : MonoBehaviour
{
    [Header("Outline")]
    public Color outlineColor = Color.black;
    [Range(1, 5)]
    public int sampleDistance = 1;
    [Range(0.0001f, 1.0f)]
    public float depthThreshold = 0.5f;
    [Range(0.001f, 1.0f)]
    public float normalThreshold = 0.995f;

    public Texture2D distortionTex;
    [Range(0.0f, 20.0f)]
    public float distortionPower = 0.1f;

    [Header("Outline Checker")]
    public bool enableEdgeChecker;
    public Color backgroundColor = Color.yellow;

    [HideInInspector]
    public Shader outlineShader;
    private Material outlineMaterial;

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(outlineShader, ref outlineMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        outlineMaterial.SetColor("_OutlineColor", outlineColor);
        outlineMaterial.SetInt("_SampleDistance", sampleDistance);
        Vector2 sampleThresholds = new Vector2 (depthThreshold, normalThreshold);
        outlineMaterial.SetVector("_SampleThresholds", sampleThresholds);

        outlineMaterial.SetTexture("_DistortionTex", distortionTex);
        outlineMaterial.SetFloat("_DistortionPower", distortionPower);


        outlineMaterial.DisableKeyword("EDGE_CHECKER");
        if (enableEdgeChecker) 
        {
            outlineMaterial.SetColor("_BackgroundColor", backgroundColor);
            outlineMaterial.EnableKeyword("EDGE_CHECKER");
        }

        Graphics.Blit(_source, _destination, outlineMaterial);
    }
}
