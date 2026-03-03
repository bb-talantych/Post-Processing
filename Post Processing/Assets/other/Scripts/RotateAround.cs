using UnityEngine;

public class RotateAround : MonoBehaviour
{
    public float rotationSpeed = 20.0f;
    void FixedUpdate()
    {
        transform.RotateAround(transform.position, Vector3.up, -rotationSpeed / 20.0f);
    }
}
