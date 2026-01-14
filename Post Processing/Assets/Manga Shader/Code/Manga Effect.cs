using UnityEngine;
using UnityEngine.Rendering;
using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class MangaEffect : MonoBehaviour
{
    public Texture image;
    public bool useImage = false;
    public bool capturing = false;
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

    public Texture paperTexture;

    [HideInInspector]
    public Shader mangaShader;
    private Material mangaMaterial = null;

    private enum ShaderPasses
    { 
        BlurPass,
        Luminocity,
        CalculateIntensityPass,
        CalculateIntensityPassFull,
        MagnitudeThresholdingPass,
        DoubleThreshold,
        Hysteresis,
        Color
    }

    void OnDisable()
    {
        mangaMaterial = null;
    }

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(mangaShader, ref mangaMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        mangaMaterial.DisableKeyword("BOX_BLUR");
        mangaMaterial.DisableKeyword("GAUSSIAN_BLUR");
        switch (blurType)
        {
            case BlurTypes.Box:
                mangaMaterial.EnableKeyword("BOX_BLUR");
                break;
            case BlurTypes.Gaussian:
                mangaMaterial.EnableKeyword("GAUSSIAN_BLUR");
                break;
        }
        mangaMaterial.DisableKeyword("PREWITT");
        mangaMaterial.DisableKeyword("SCHARR");
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
        mangaMaterial.SetTexture("_PaperTex", paperTexture);

        int width = useImage ? image.width : _source.width;
        int height = useImage ? image.height : _source.height;

        RenderTexture edgeSource = RenderTexture.GetTemporary(width, height, 0, _source.format);

        #region Canny Edge Detection
        RenderTexture blurSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(useImage ? image : _source, blurSource, mangaMaterial,
            (int)ShaderPasses.BlurPass);

        RenderTexture luminocitySource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(blurSource, luminocitySource, mangaMaterial,
            (int)ShaderPasses.Luminocity);

        RenderTexture calculateIntensitySource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(luminocitySource, calculateIntensitySource, mangaMaterial,
            (int)ShaderPasses.CalculateIntensityPassFull);

        RenderTexture magnitudeThresholdingSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(calculateIntensitySource, magnitudeThresholdingSource, mangaMaterial,
            (int)ShaderPasses.MagnitudeThresholdingPass);

        RenderTexture doubleThresholdSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(magnitudeThresholdingSource, doubleThresholdSource, mangaMaterial,
            (int)ShaderPasses.DoubleThreshold);

        Graphics.Blit(doubleThresholdSource, edgeSource, mangaMaterial,
            (int)ShaderPasses.Hysteresis);

        RenderTexture.ReleaseTemporary(blurSource);
        RenderTexture.ReleaseTemporary(luminocitySource);
        RenderTexture.ReleaseTemporary(calculateIntensitySource);
        RenderTexture.ReleaseTemporary(magnitudeThresholdingSource);
        RenderTexture.ReleaseTemporary(doubleThresholdSource);

        #endregion

        Graphics.Blit(edgeSource, _destination, mangaMaterial, (int) ShaderPasses.Color);
        RenderTexture.ReleaseTemporary(edgeSource);
    }

    private void LateUpdate()
    {
        if (capturing && Input.GetKeyDown(KeyCode.Space))
        {
            int width = useImage ? image.width : 960;
            int height = useImage ? image.height : 540;

            RenderTexture rt = new RenderTexture(width, height, 24);
            GetComponent<Camera>().targetTexture = rt;
            Texture2D screenshot = new Texture2D(width, height, TextureFormat.RGB24, false);
            GetComponent<Camera>().Render();
            RenderTexture.active = rt;
            screenshot.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            GetComponent<Camera>().targetTexture = null;
            RenderTexture.active = null;
            Destroy(rt);
            string filename = string.Format("{0}/../_Screenshots/mangaEffect_{1}.png", Application.dataPath, System.DateTime.Now.ToString("HH-mm-ss"));
            System.IO.File.WriteAllBytes(filename, screenshot.EncodeToPNG());
            Debug.Log("screenshot ready");
        }
    }
}
