using UnityEngine;

namespace CameraCommon
{
    public static class BB_Rendering
    {
        public static bool ShaderMaterialReady(Shader _shader, ref Material _material)
        {
            _material = null;
            if (!_shader)
                return false;

            if (!_material)
                _material = new Material(_shader);

            return true;
        }
    }
}

