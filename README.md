# SvelteKit-Godot Integration: 3D Tour Plan Visualization

(Work in Progress)

This project demonstrates a powerful integration between SvelteKit and Godot, creating a web application that visualizes a tour plan in a 3D environment. The 3D assets and imagery are generated with the help of Gemini.

<table>
    <tr>
        <td>
            <img src="germany/Gemini_Generated_Image_u05sg1u05sg1u05s.png">
        </td>
        <td>
            <img src="germany/Gemini_Generated_Image_9odrjf9odrjf9odr.png">
        </td>
        <td>
            <img src="germany/Gemini_Generated_Image_kzi3u2kzi3u2kzi3.png">
        </td>
    </tr>
</table>

## 🚀 Motivation

The primary goal of this project is to showcase how to build a rich, interactive web experience by combining the strengths of a modern web framework (SvelteKit) with a powerful 3D game engine (Godot). This allows for the creation of immersive 3D visualizations within a standard web application.

<img src="docs/godot-html5.jpg" width=800>

The above is a Godot scene in the SvelteKit app


## ✨ Features

*   **3D Tour Visualization:** Explore a tour plan in a 3D environment.
*   **SvelteKit Integration:** Seamlessly embed the Godot application within a SvelteKit web app.
*   **AI-Generated Assets:** All images and 3D model textures are generated using Gemini.

## 🛠️ Technologies Used

*   **SvelteKit:** A modern web application framework for building high-performance web apps.
*   **Godot:** A powerful open-source game engine for creating 2D and 3D games and interactive experiences.
*   **Gemini:** Used for generating the images and textures for the 3D models.

## ⚙️ Integration

To integrate the Godot application into the SvelteKit app, follow these steps:

1.  **Export Godot Project:** Open your Godot project. Go to `Project` -> `Export...`.
2.  **Add HTML5 Preset:** If you don't have an HTML5 preset, click `Add...` and select `HTML5`.
3.  **Set Export Path:** In the HTML5 preset settings, set the `Path` to `app/static/` within your project directory. This will export the Godot project directly into the SvelteKit static assets folder.
4.  **Export:** Click `Export Project`.

After exporting, the Godot application files (e.g., `godot.html`, `godot.js`, `godot.wasm`, `godot.pck`) will be available in the `app/static/` directory of your SvelteKit project, ready to be served.
