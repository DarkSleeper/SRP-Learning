#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

float4x4 unity_ObjectToWorld; // uniform
float4x4 unity_WorldToObject;

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_Matrix_M;
float4x4 unity_prev_Matrix_IM;
float4x4 glstate_matrix_projection;
real4 unity_WorldTransformParams;

#endif

