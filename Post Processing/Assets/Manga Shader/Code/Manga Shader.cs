using UnityEngine;
using UnityEngine.Rendering;
using CameraCommon;

[ImageEffectAllowedInSceneView, ExecuteInEditMode]
public class MangaShader : MonoBehaviour
{
    [SerializeField]
    private Shader mangaShader;
    private Material mangaMaterial;

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!BB_Rendering.ShaderMaterialReady(mangaShader, ref mangaMaterial))
        {
            Graphics.Blit(_source, _destination);
        }
            

        Graphics.Blit(_source, _destination, mangaMaterial);
    }
}
