using UnityEngine;

using CameraCommon;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class SharpnessEffect : MonoBehaviour
{
    [Range(0, 10.0f)]
    public float sharpness = 1;

    [HideInInspector]
    public Shader sharpness_Shader;
    private Material sharpnessMaterial;

    private void OnDisable()
    {
        sharpnessMaterial = null; 
    }

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(sharpness_Shader, ref sharpnessMaterial))
        {
            Graphics.Blit(_source, _destination);
            return;
        }

        sharpnessMaterial.SetFloat("_Sharpness", sharpness);

        Graphics.Blit(_source, _destination, sharpnessMaterial);
    }

}
