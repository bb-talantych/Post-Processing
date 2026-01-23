using UnityEngine;
using UnityEngine.Rendering;
using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class Depth_OutlineEffect : MonoBehaviour
{
    [Header("Outline")]
    public Color outlineColor = Color.black;
    [Range(1, 7)]
    public int sampleDistance = 1;
    [Range(0.0001f, 1.0f)]
    public float depthThreshold = 0.0001f;

    [HideInInspector]
    public Shader outlineShader;
    private Material outlineMaterial = null;

    private enum Passes
    {
        Sobel,
        LineWidth
    };

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if (!BB_Rendering.ShaderMaterialReady(outlineShader, ref outlineMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        outlineMaterial.SetColor("_OutlineColor", outlineColor);
        outlineMaterial.SetInt("_SampleDistance", sampleDistance);
        outlineMaterial.SetFloat("_DepthThreshold", depthThreshold);

        outlineMaterial.SetTexture("_Source", _source);

        int width = _source.width;
        int height = _source.height;

        RenderTexture sobelSource = RenderTexture.GetTemporary(width, height, 0, _source.format); 

        Graphics.Blit(_source, sobelSource, outlineMaterial, (int)Passes.Sobel);
        Graphics.Blit(sobelSource, _destination, outlineMaterial, (int)Passes.LineWidth);

        RenderTexture.ReleaseTemporary(sobelSource);
    }
}
