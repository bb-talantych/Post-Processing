using UnityEngine;
using UnityEngine.Rendering;
using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class MangaEffect : MonoBehaviour
{
    #region Enums
    public enum BlurTypes
    {
        None,
        Box,
        Gaussian
    };
    public enum Operators
    {
        Sobel,
        Prewitt,
        Scharr
    };

    public enum MagThresholdingTypes
    {
        Alpha,
        Gx,
        Gx_N_Gy
    };

    private enum ShaderPasses
    {
        BlurPass,
        Luminance,
        CalculateIntensityPass,
        MagnitudeThresholdingPass,
        DoubleThreshold,
        Hysteresis,
        Color
    }
    #endregion

    [Header("Settings")]
    public Texture image;
    public bool hideEffect = false;
    public bool useImage = false;
    public bool capturing = false;


    [Header("Canny Edge Detection")]
    [Tooltip("Gaussian blur is abysmal for post processing, don't use it." +
    " I included it just because the original canny edge detection does")]
    public BlurTypes blurType = BlurTypes.None;
    public Operators operatorType = Operators.Sobel;
    public MagThresholdingTypes magThresholdingType = MagThresholdingTypes.Alpha;

    [Range(0.01f, 1.0f)]
    public float highThreshold = 0.8f;
    [Range(0.01f, 1.0f)]
    public float lowThreshold = 0.1f;

    public Color outlineColor = Color.black;

    [Header("Manga Properties")]
    [Range(0, 1.0f)]
    public float lightThreshold = 0.75f;
    [Range(0, 1.0f)]
    public float shadowThreshold= 0.25f;

    public Color backgroundColor = new Color(1, 0.7659675f, 0, 0);
    public Color shadowColor = Color.black;
    public Texture paperTexture;

    [Header("Hatch Properties")]
    public Texture hatchTexture;
    public Vector2 hatchTiling = new Vector2(1.777778f, 1);
    [Range(0.01f, 10.0f)]
    public float hatchTilingScale = 5;
    [Range(0.0f, 360.0f)]
    public float hatchRotation = 0;
    [Range(0.0f, 360.0f)]
    public float secondaryHatchRotation = 0;

    public Color mainHatchColor = Color.gray;
    public Color secondaryHatchColor = Color.black;

    [Range(0, 1.0f)]
    public float mainHatchingThreshold = 0.8f;
    [Range(0, 1.0f)]
    public float secondaryHatchingThreshold = 0.2f;
    [Range(0, 1.0f)]
    public float hatchBlendingTreshold = 0.8f;
    [Range(0, 1.0f)]
    public float secondaryHatchBlendingTreshold = 0.2f;


    [HideInInspector]
    public Shader mangaShader;
    private Material mangaMaterial = null;
    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(mangaShader, ref mangaMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        int width = useImage ? image.width : _source.width;
        int height = useImage ? image.height : _source.height;
        //int width = _source.width;
        //int height = _source.height;

        Texture startingSource = useImage ? image : _source;

        if (hideEffect)
        {
            Graphics.Blit(startingSource, _destination);
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
        mangaMaterial.DisableKeyword("GX");
        mangaMaterial.DisableKeyword("GX_N_GY");
        switch (magThresholdingType)
        {
            case MagThresholdingTypes.Gx:
                mangaMaterial.EnableKeyword("GX");
                break;
            case MagThresholdingTypes.Gx_N_Gy:
                mangaMaterial.EnableKeyword("GX_N_GY");
                break;
        }

        mangaMaterial.SetFloat("_HighThreshold", highThreshold);
        mangaMaterial.SetFloat("_LowThreshold", lowThreshold);
        mangaMaterial.SetColor("_OutlineColor", outlineColor);

        Vector4 luminanceThresholds = new Vector4(lightThreshold, mainHatchingThreshold, secondaryHatchingThreshold, shadowThreshold); 
        mangaMaterial.SetVector("_LuminanceThresholds", luminanceThresholds);
        mangaMaterial.SetColor("_BackgroundColor", backgroundColor);
        mangaMaterial.SetColor("_ShadowColor", shadowColor);
        mangaMaterial.SetTexture("_PaperTex", paperTexture);

        mangaMaterial.SetTexture("_HatchTex", hatchTexture);
        mangaMaterial.SetVector("_HatchTiling", hatchTiling * hatchTilingScale);
        mangaMaterial.SetFloat("_HatchRotation", hatchRotation);
        mangaMaterial.SetFloat("_SecondaryHatchRotation", secondaryHatchRotation);
        mangaMaterial.SetColor("_MainHatchColor", mainHatchColor);
        mangaMaterial.SetColor("_SecondaryHatchColor", secondaryHatchColor);
        mangaMaterial.SetFloat("_HatchBlendingTreshold", hatchBlendingTreshold);
        mangaMaterial.SetFloat("_SecondaryHatchBlendingTreshold", secondaryHatchBlendingTreshold);

        RenderTexture cannySource = RenderTexture.GetTemporary(width, height, 0, _source.format);

        #region Canny Edge Detection
        RenderTexture luminanceSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(startingSource, luminanceSource, mangaMaterial,
            (int)ShaderPasses.Luminance);

        mangaMaterial.SetTexture("_LuminanceTex", luminanceSource);

        RenderTexture blurSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(luminanceSource, blurSource, mangaMaterial,
            (int)ShaderPasses.BlurPass);

        RenderTexture calculateIntensitySource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(blurSource, calculateIntensitySource, mangaMaterial,
            (int)ShaderPasses.CalculateIntensityPass);

        RenderTexture magnitudeThresholdingSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(calculateIntensitySource, magnitudeThresholdingSource, mangaMaterial,
            (int)ShaderPasses.MagnitudeThresholdingPass);

        RenderTexture doubleThresholdSource =
            RenderTexture.GetTemporary(width, height, 0, _source.format);
        Graphics.Blit(magnitudeThresholdingSource, doubleThresholdSource, mangaMaterial,
            (int)ShaderPasses.DoubleThreshold);

        Graphics.Blit(doubleThresholdSource, cannySource, mangaMaterial,
            (int)ShaderPasses.Hysteresis);

        // testing
        //Graphics.Blit(cannySource, _destination);

        RenderTexture.ReleaseTemporary(luminanceSource);
        RenderTexture.ReleaseTemporary(blurSource);
        RenderTexture.ReleaseTemporary(calculateIntensitySource);
        RenderTexture.ReleaseTemporary(magnitudeThresholdingSource);
        RenderTexture.ReleaseTemporary(doubleThresholdSource);

        #endregion

        Graphics.Blit(cannySource, _destination, mangaMaterial, (int)ShaderPasses.Color);
        RenderTexture.ReleaseTemporary(cannySource);

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
