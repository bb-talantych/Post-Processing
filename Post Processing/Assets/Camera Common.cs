using UnityEngine;

namespace CameraCommon
{
    public static class BB_Rendering
    {
        public static bool ShaderMaterialReady(Shader _shader, ref Material _material)
        {
            if (!_shader)
                return false;

            if (!_material)
            {
                _material = new Material(_shader);
                _material.hideFlags = HideFlags.HideAndDontSave;
            }

            return true;
        }
    }
}

