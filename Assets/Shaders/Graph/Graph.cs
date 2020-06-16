using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[ExecuteInEditMode]
public class Graph : MonoBehaviour
{
    private Image image;

    void Start()
    {
        image = GetComponent<Image>();
    }

    void Update()
    {
        float mul = 0.5f;

        List<Vector4> array = new List<Vector4>();
        for(int i=0; i<25; i++){
            array.Add(new Vector4(Time.time+i*mul, Mathf.Sin(Time.time+i*mul)));
        }
        
        image.material.SetVectorArray("_Data", array.ToArray());
    }
}
