# WebGPU Ray Marching Scene Editor

##gitScene Editor Preview
<img src="./images/overview.png" width="600">

[**Click Here For Live Demo**](https://oscarinho7.github.io/WebGPU-Project-Interactive-Ray-Marching-Scene-Editor/)

## Overview
A powerful, interactive 3D scene editor built with WebGPU and Ray Marching. This application allows users to manipulate 3D primitives in real-time using a custom UI panel, demonstrating the power of modern web graphics.

## Features
-   **Real-time Ray Marching**: Renders complex 3D scenes using signed distance functions (SDFs).
-   **Interactive Scene Panel**: Modify object properties (position, size, color) on the fly.
-   **Dynamic Uniforms**: Seamlessly updates WebGPU uniform buffers without recompilation.
-   **Shader Editor**: Built-in code editor to modify WGSL shaders directly.

## Tech Stack
-   **WebGPU**: Next-generation graphics API for the web.
-   **WGSL**: WebGPU Shading Language.
-   **JavaScript**: Core application logic and UI management.
-   **TailwindCSS**: Modern styling for the user interface.

## Local Development
1.  Clone the repository.
2.  Navigate to the project directory.
3.  Start a local server (required for WebGPU security policies):
    ```bash
    python -m http.server
    ```
4.  Open your browser to `http://localhost:8000`.




