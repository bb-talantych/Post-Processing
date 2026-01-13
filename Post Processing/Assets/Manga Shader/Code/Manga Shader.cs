using UnityEngine;
using UnityEngine.Rendering;


[ImageEffectAllowedInSceneView, ExecuteInEditMode]
public class MangaShader : MonoBehaviour
{
    [SerializeField]
    private Shader mangaShader;
    private Material mangaMaterial;

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        if(!ShaderMaterialReady(mangaShader, ref mangaMaterial))
        {
            Graphics.Blit(_source, _destination);
        }
            

        Graphics.Blit(_source, _destination, mangaMaterial);
    }

    bool ShaderMaterialReady(Shader _shader, ref Material _material)
    {
        _material = null;
        if (!_shader)
            return false;

        if (!_material)
            _material = new Material(_shader);

        return true;
    }
}
