using UnityEngine;
using UnityEngine.Rendering;
using CameraCommon;

[ImageEffectAllowedInSceneView, ExecuteInEditMode]
public class MangaEffect : MonoBehaviour
{
    [SerializeField]
    private Shader mangaShader;
    private Material mangaMaterial;

    public enum BlurTypes
    {
        None,
        Box,
        Gaussian
    };
    [Tooltip("Gaussian blur is abysmal for post processing, don't use it." +
        " I included it just because the original canny edge detection does")]
    public BlurTypes blurType = BlurTypes.None;

    public enum Operators
    {
        Sobel,
        Prewitt,
        Scharr
    };
    public Operators operatorType = Operators.Sobel;

    [Range(0.01f, 1.0f)]
    public float highThreshold = 0.8f;

    [Range(0.01f, 1.0f)]
    public float lowThreshold = 0.1f;

    private enum ShaderPasses
    { 
        BlurPass,
        Luminocity,
        CalculateIntensityPass,
        CalculateIntensityPassFull,
        MagnitudeThresholdingPass,
        DoubleThreshold,
        Hysteresis
    }

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(mangaShader, ref mangaMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        int width = _source.width;
        int height = _source.height;

        RenderTexture edgeSource = RenderTexture.GetTemporary(width, height, 0, _source.format);

        switch (blurType)
        {
            case BlurTypes.Gaussian:
                mangaMaterial.EnableKeyword("GAUSSIAN_BLUR");
                break;
            case BlurTypes.Box:
                mangaMaterial.EnableKeyword("BOX_BLUR");
                break;
        }
        switch (operatorType)
        {
            case Operators.Prewitt:
                mangaMaterial.EnableKeyword("PREWITT");
                break;
            case Operators.Scharr:
                mangaMaterial.EnableKeyword("SCHARR");
                break;
        }
        mangaMaterial.SetFloat("_HighThreshold", highThreshold);
        mangaMaterial.SetFloat("_LowThreshold", lowThreshold);

        #region Canny Edge Detection
        RenderTexture blurSource =
            RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(_source, blurSource, mangaMaterial,
            (int)ShaderPasses.BlurPass);

        RenderTexture luminocitySource =
            RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(blurSource, luminocitySource, mangaMaterial,
            (int)ShaderPasses.Luminocity);

        RenderTexture calculateIntensitySource = 
            RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(luminocitySource, calculateIntensitySource, mangaMaterial,
            (int)ShaderPasses.CalculateIntensityPassFull);

        RenderTexture magnitudeThresholdingSource =
            RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(calculateIntensitySource, magnitudeThresholdingSource, mangaMaterial,
            (int)ShaderPasses.MagnitudeThresholdingPass);

        RenderTexture doubleThresholdSource =
            RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(magnitudeThresholdingSource, doubleThresholdSource, mangaMaterial,
            (int)ShaderPasses.DoubleThreshold);

        RenderTexture hysteresisSource =
            RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGBFloat);
        Graphics.Blit(doubleThresholdSource, hysteresisSource, mangaMaterial,
            (int)ShaderPasses.Hysteresis);

        Graphics.Blit(hysteresisSource, edgeSource);

        RenderTexture.ReleaseTemporary(blurSource);
        RenderTexture.ReleaseTemporary(luminocitySource);
        RenderTexture.ReleaseTemporary(calculateIntensitySource);
        RenderTexture.ReleaseTemporary(magnitudeThresholdingSource);
        RenderTexture.ReleaseTemporary(doubleThresholdSource);
        RenderTexture.ReleaseTemporary(hysteresisSource);

        #endregion



        Graphics.Blit(edgeSource, _destination);
    }
}
