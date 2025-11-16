<script>
    import jsQR from "jsqr";
    import { onMount } from "svelte";

    /**
     * Component properties for configuring the QR code reader.
     * @prop {number} [z_index=10] - The z-index for the overlay canvas.
     * @prop {boolean} [enabled=false] - Toggles the QR code reader's active state.
     * @prop {string | null} [qr_code=null] - A bindable property that holds the decoded QR code data.
     * @prop {(msg: string) => void | null} [updateStatus=null] - A callback function to update the status message in the parent component.
     * @prop {() => string} [captureImage] - A bindable function that captures the current video frame and returns it as a base64 string.
     */
    let {
        z_index = 10,
        enabled = false,
        qr_code = $bindable(),
        updateStatus = null,
        captureImage = $bindable(),
    } = $props();

    /**
     * State variables for DOM element bindings.
     * - video: The <video> element that displays the live camera feed.
     * - canvas: An off-screen canvas to capture video frames for analysis.
     * - rectCanvas: An on-screen canvas to draw a rectangle around a detected QR code.
     */
    let video = $state();
    let canvas = $state();
    let rectCanvas = $state();

    /**
     * Draws a rectangle on the canvas to highlight the detected QR code.
     * This is done by creating a single path connecting the corner points and stroking it.
     * @param {CanvasRenderingContext2D} ctx - The rendering context of the canvas to draw on.
     * @param {object} location - The location object from the jsQR library, containing the corner points of the QR code.
     */
    const drawRect = (ctx, location) => {
        ctx.beginPath();
        ctx.moveTo(location.topLeftCorner.x, location.topLeftCorner.y);
        ctx.lineTo(location.topRightCorner.x, location.topRightCorner.y);
        ctx.lineTo(location.bottomRightCorner.x, location.bottomRightCorner.y);
        ctx.lineTo(location.bottomLeftCorner.x, location.bottomLeftCorner.y);
        ctx.closePath();
        ctx.lineWidth = 4;
        ctx.strokeStyle = "blue";
        ctx.stroke();
    };

    /**
     * Manages the QR code reading process. When enabled, it requests access to the
     * device's rear camera. Once the video stream is active, it continuously
     * captures frames, scans them for a QR code using jsQR, and highlights any
     * detected code on an overlay canvas. When disabled, it stops the camera stream
     * to release resources. It also handles and reports errors, such as when
     * camera access is denied.
     */
    const startReadingQrCode = async () => {
        /**
         * Defines the media constraints for `getUserMedia`. It requests only video
         * from the rear-facing camera ("environment") and disables audio.
         */
        const constraints = {
            audio: false,
            video: {
                facingMode: "environment", // Specifies the rear camera
            },
        };

        if (enabled) {
            try {
                // Prompt for camera access and assign the resulting MediaStream to the video element.
                video.srcObject =
                    await navigator.mediaDevices.getUserMedia(constraints);

                //updateStatus("Camera access granted. Starting capture...");

                /**
                 * This event handler is triggered once the video's metadata is loaded.
                 * It starts video playback, sets up the canvases for QR code scanning, and
                 * initiates a recurring loop (`scanFrame`) to continuously analyze video
                 * frames for QR codes.
                 */
                video.onloadeddata = () => {
                    video.play();
                    /**
                     * A recursive function that continuously scans for QR codes.
                     * It draws the current video frame to a canvas, gets the image data,
                     * and uses the jsQR library to detect a code. If a code is found, it is
                     * highlighted and its data is stored. The function then uses
                     * `requestAnimationFrame` to schedule the next scan, synchronizing it
                     * with the browser's rendering cycle for optimal performance.
                     */

                    // Set the dimensions of both the off-screen capture canvas and the
                    // on-screen overlay canvas to match the video element's display size.
                    // This ensures that the captured image data and the drawn rectangle
                    // align correctly with the visible video feed.
                    const videoWidth = video.videoWidth;
                    const videoHeight = video.videoHeight;
                    const dWidth = video.clientWidth;
                    const dHeight = video.clientHeight;

                    /*
                    console.log("video", contentWidth, contentHeight);
                    console.log("video2", video.videoWidth, video.videoHeight);
                    console.log("canvas", canvas.width, canvas.height);
                    console.log("rect", rectCanvas.width, rectCanvas.height);
                    console.log("window", window.innerWidth, window.innerHeight);
                    */

                    // Set the dimensions of both the off-screen capture canvas and the
                    // on-screen overlay canvas to match the video element's display size.
                    // This ensures that the captured image data and the drawn rectangle
                    // align correctly with the visible video feed.
                    canvas.width = dWidth;
                    canvas.height = dHeight;
                    rectCanvas.width = dWidth;
                    rectCanvas.height = dHeight;

                    //https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/drawImage
                    // Calculate the source rectangle (sx, sy, sWidth, sHeight) from the video
                    // and the destination rectangle (dx, dy, dWidth, dHeight) on the canvas.
                    // This logic mimics the behavior of `object-fit: cover`. It ensures the video
                    // fills the canvas while maintaining the display's aspect ratio, cropping
                    // any excess video content (in this case, horizontally) to prevent distortion.
                    const sx =
                        (videoWidth - (videoHeight * dWidth) / dHeight) / 2;
                    const sy = 0;
                    const sWidth = videoWidth - sx * 2;
                    const sHeight = videoHeight;
                    const dx = 0;
                    const dy = 0;
                    //console.log(sx, " ", sy, " ", sWidth, " ", sHeight, " ", dx, " ", dy, " ", dWidth, " ", dHeight);

                    const scanFrame = () => {
                        /**
                         * Get the 2D rendering contexts for both canvases.
                         * - `ctx`: For the off-screen canvas to capture and analyze video frames.
                         *   The `willReadFrequently: true` hint optimizes performance for frequent reads.
                         * - `rectCtx`: For the on-screen canvas to draw the highlight rectangle.
                         */
                        const ctx = canvas.getContext("2d", {
                            willReadFrequently: true,
                        });
                        const rectCtx = rectCanvas.getContext("2d");

                        // Draw the current video frame onto the off-screen canvas and then
                        // extract its raw pixel data. This data is what the jsQR library
                        // will analyze to find a QR code.
                        ctx.drawImage(
                            video,
                            sx,
                            sy,
                            sWidth,
                            sHeight,
                            dx,
                            dy,
                            dWidth,
                            dHeight,
                        );

                        const imageData = ctx.getImageData(
                            0,
                            0,
                            dWidth,
                            dHeight,
                        );

                        // Use the jsQR library to scan the captured image data for a QR code.
                        // It returns a code object if found, otherwise null.
                        const code = jsQR(imageData.data, dWidth, dHeight);

                        rectCtx.clearRect(0, 0, dWidth, dHeight);
                        // If a QR code is detected, clear the previous rectangle, draw a new
                        // one around the code's location, update the parent component's status,
                        // log the result, and update the bindable `qr_code` property with the
                        // decoded data, ensuring the data is not empty.
                        if (code && code.data !== "") {
                            drawRect(rectCtx, code.location);
                            updateStatus(`QR code found: ${code.data}`);
                            console.log(`QR code found: ${code.data}`);
                            qr_code = code.data;
                        }

                        // If the reader is still enabled, schedule the next frame scan.
                        if (enabled) {
                            requestAnimationFrame(scanFrame);
                        }
                    };
                    // Start the scanning loop.
                    scanFrame();
                };
            } catch (e) {
                console.error("Error accessing camera:", e);
                updateStatus(`Camera Error: ${e.message}`);
            }
        } else {
            // If the reader is disabled, stop all video tracks to release the camera
            // and turn off the recording indicator. This is a crucial cleanup step
            // to free up resources when the component is no longer active.
            if (video.srcObject) {
                const tracks = video.srcObject.getTracks();
                tracks.forEach((track) => {
                    track.stop();
                });
                video.srcObject = null;
            }
        }
    };

    /**
     * Captures the current video frame, converts it to a base64-encoded JPEG image,
     * and returns the data. This can be used for features like taking a snapshot.
     * @returns {string} The base64-encoded JPEG image data.
     */
    captureImage = () => {
        const ctx = canvas.getContext("2d");
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        const imageURL = canvas.toDataURL("image/jpeg").split(",")[1];
        return imageURL;
    };

    /**
     * A reactive effect that triggers whenever the `enabled` prop changes.
     * It calls `startReadingQrCode()` to either initiate or terminate the
     * camera stream and scanning process based on the new value.
     */
    $effect(() => {
        enabled;
        startReadingQrCode();
    });

    onMount(() => {
        // Request fullscreen and lock orientation to portrait on component mount.
        // This provides a more consistent user experience for camera-based interactions.
        document.documentElement.requestFullscreen();
        try {
            screen.orientation.lock("portrait-primary"); // Force portrait mode
        } catch (e) {
            console.log(e);
        }
    });
</script>

<!--
    This container holds all the camera-related elements. It is shown or hidden
    based on the `enabled` prop, controlling the visibility of the entire component.
-->
<div
    style="width: 100vw; height: 100vh; background-color: #100C14; {enabled
        ? 'display: block'
        : 'display: none'}"
>
    <!--
        This <video> element is the core of the camera functionality. It is not
        directly visible to the user. Instead, its frames are captured and drawn
        onto the canvases for processing and display.
        - `autoplay`: Ensures the video stream starts as soon as it's available.
        - `bind:this={video}`: Binds this DOM element to the `video` variable for script access.
        - `object-fit: cover`: Makes the video fill its container while maintaining aspect ratio,
          which is important for the `drawImage` calculations that mimic this behavior on the canvas.
    -->
    <!-- svelte-ignore a11y_media_has_caption -->
    <video
        style="width: 100vw; height: 100vh; object-fit: cover;"
        autoplay
        bind:this={video}
    > <!-- svelte-ignore a11y_media_has_caption --></video>
    <!--
        An off-screen canvas used for capturing frames from the video element.
        It's hidden from view but is essential for getting the image data that
        is fed into the jsQR library for analysis.
    -->
    <canvas style="position: absolute; top:0; left:0; visibility: hidden;" bind:this={canvas}
    ></canvas>
    <canvas
        style="position: absolute; top:0; left:0; z-index: {z_index};"
        bind:this={rectCanvas}
    ></canvas>
</div>
