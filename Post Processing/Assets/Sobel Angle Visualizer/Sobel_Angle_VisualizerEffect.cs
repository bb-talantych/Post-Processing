using UnityEngine;
using UnityEngine.Rendering;
using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class Sobel_Angle_VisualizerEffect : MonoBehaviour
{
    public Color Up = Color.blue;
    public Color Down = Color.red;
    public Color Right = Color.yellow;
    public Color Left = Color.green;

    [HideInInspector]
    public Shader visualizerShader;
    private Material visualizerMaterial = null;

    private enum Passes
    {
        Sobel,
        Visualizer
    };

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if (!BB_Rendering.ShaderMaterialReady(visualizerShader, ref visualizerMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        visualizerMaterial.SetColor("_UpCol", Up);
        visualizerMaterial.SetColor("_DownCol", Down);
        visualizerMaterial.SetColor("_RightCol", Right);
        visualizerMaterial.SetColor("_LeftCol", Left);

        int width = _source.width;
        int height = _source.height;

        RenderTexture sobelSource = RenderTexture.GetTemporary(width, height, 0, _source.format);

        Graphics.Blit(_source, sobelSource, visualizerMaterial, (int)Passes.Sobel);
        Graphics.Blit(sobelSource, _destination, visualizerMaterial, (int)Passes.Visualizer);

        RenderTexture.ReleaseTemporary(sobelSource);
    }
}
