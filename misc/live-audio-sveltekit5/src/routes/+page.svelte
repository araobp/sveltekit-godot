<script>
  import { onMount } from "svelte";
  import { GoogleGenAI, Modality } from "@google/genai";
  import { createBlob, decode, decodeAudioData } from "$lib/utils";
  import Visual3d from "$lib/Visual3d.svelte";

  /**
   * Reactive state variables for managing the component's UI.
   * - isRecording: Tracks the recording status to toggle controls.
   * - status: Displays informational messages to the user.
   * - error: Displays error messages.
   */
  let isRecording = $state(false);
  let status = $state("");
  let error = $state(null);

  // These variables will hold the Google Gemini client instance and the active
  // live session object for real-time communication.
  let client;
  let session;

  // Two separate AudioContexts are used to handle input and output independently.
  // This allows for different sample rates: 16kHz for microphone capture (input)
  // and 24kHz for audio playback from the model (output), simplifying the audio pipeline.
  let inputAudioContext;
  let outputAudioContext;
  
  // These reactive state variables hold the GainNodes for the input (microphone)
  // and output (speaker) audio streams. They act as the primary connection
  // points for audio processing and are passed to the Visual3d component
  // for visualization purposes.
  let inputNode = $state();
  let outputNode = $state();

  /**
   * Tracks the scheduled start time for the next audio chunk. This is crucial
   * for queueing audio buffers to play back-to-back without gaps or overlaps,
   * creating a seamless audio stream.
   */
  let nextStartTime = 0;
  
  /**
   * Holds the MediaStream object from the user's microphone, obtained via
   * `navigator.mediaDevices.getUserMedia`. This stream is the source of the
   * live audio input.
   */
  let mediaStream;

  /**
   * Represents the audio source node created from the microphone's media stream.
   * This is the entry point for the audio input graph.
   */
  let sourceNode;

  /**
   * The AudioWorkletNode that runs the custom 'audio-processor.js' script.
   * This node processes raw audio from the microphone in a separate thread,
   * converting it to PCM data, which is then sent to the Gemini model.
   */
  let audioWorkletNode;

  // This Set holds all the active AudioBufferSourceNodes that are currently
  // playing or scheduled to play. This is crucial for managing interruptions:
  // if the user starts speaking, all sources in this set are stopped immediately.
  let sources = new Set();

  onMount(() => {
    // The window.AudioContext is the main entry point and container
    // for all audio operations within the Web Audio API. 
    inputAudioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: 16000,
    });
    outputAudioContext = new (window.AudioContext || window.webkitAudioContext)(
      { sampleRate: 24000 },
    );

    // The createGain() method in the Web Audio API creates a GainNode,
    // which is used to control the overall volume (or gain) of an audio signal.
    inputNode = inputAudioContext.createGain();
    outputNode = outputAudioContext.createGain();

    initClient();
  });


  /**
   * Initializes the Google Gemini client and Web Audio API components.
   */
  const initClient = async () => {
    // The AudioContext.currentTime property is a read-only value
    // that returns the current time in seconds, measured from the moment
    // the AudioContext was first created.
    nextStartTime = outputAudioContext.currentTime;

    // Google Gemini Client
    client = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });

    // Connect the output gain node to the speakers (final destination),
    // so we can hear the audio.
    outputNode.connect(outputAudioContext.destination);

    initSession();
  };

  /**
   * Establishes a real-time, bidirectional communication session with the
   * Google Gemini model. It configures the model to use and sets up
   * callbacks to handle the entire lifecycle of the connection, including
   * receiving audio data and managing interruptions.
   */
  const initSession = async () => {
    // Specifies the Gemini model optimized for real-time, native audio dialogue.
    // This model is designed for fast, conversational interactions.
    const model = "gemini-2.5-flash-preview-native-audio-dialog";

    // Establish a real-time, bidirectional connection to the Gemini model,
    // setting up callbacks to handle incoming audio data, interruptions,
    // and connection status changes.
    try {
      session = await client.live.connect({
        model: model,
        callbacks: {
          // This function is called once the connection to the model is
          // successfully established.
          onopen: () => {
            updateStatus("Opened");
          },

          // This callback handles messages from the server. It processes incoming
          // audio chunks for seamless playback and manages interruptions if the
          // user starts speaking over the model's response.
          onmessage: async (message) => {
            const audio =
              // Safely extract the inline audio data from the model's response
              // using optional chaining.
              message.serverContent?.modelTurn?.parts[0]?.inlineData;

            if (audio) {
              // Synchronize the next start time. This ensures that audio plays
              // immediately after the previous chunk finishes, or right now if
              // there has been a delay or interruption. It prevents scheduling
              // audio in the past.
              nextStartTime = Math.max(
                nextStartTime,
                outputAudioContext.currentTime,
              );

              // Decode the base64 audio data from the server into a playable
              // AudioBuffer. This involves a two-step decoding process: first from
              // base64 to a raw byte array, then from that array into the
              // Web Audio API's buffer format.
              const audioBuffer = await decodeAudioData(
                decode(audio.data),
                outputAudioContext,
                24000,
                1,
              );

              // Create a new audio source for this chunk, assign the decoded
              // audio buffer to it, and connect it to the output gain node
              // so it can be heard.
              const source = outputAudioContext.createBufferSource();
              source.buffer = audioBuffer;
              source.connect(outputNode);

              // Register a cleanup function to run when this audio chunk finishes
              // playing. This removes the source from the tracking Set to prevent
              // memory leaks and keep the interruption logic efficient.
              source.addEventListener("ended", () => {
                sources.delete(source);
              });

              // Schedule this audio chunk to play at the calculated start time,
              // ensuring gapless playback.
              source.start(nextStartTime);

              // Advance the start time for the next audio chunk by the duration
              // of the current one, ensuring seamless, gapless playback.
              nextStartTime = nextStartTime + audioBuffer.duration;

              // Add the source to the tracking set. This allows the interruption
              // logic to stop all currently playing or scheduled audio.
              sources.add(source);
            }

            // Check if the model's speech was interrupted by the user starting to speak.
            const interrupted = message.serverContent?.interrupted;
            
            // If an interruption is detected, immediately stop all currently
            // playing or scheduled audio sources from the model. This makes the
            // conversation feel more natural and responsive. Reset the
            // playback start time to ensure the next audio chunk plays
            // without delay.
            if (interrupted) {
              for (const source of sources.values()) {
                source.stop();
                sources.delete(source);
              }
              nextStartTime = 0;
            }
          },

          onerror: (e) => {
            updateError(e.message);
          },

          onclose: (e) => {
            updateStatus("Close:" + e.reason);
          },
        },
        config: {
          responseModalities: [Modality.AUDIO],
          speechConfig: {
            voiceConfig: { prebuiltVoiceConfig: { voiceName: "Leda" } },
            // languageCode: 'en-GB'
          },
        },
      });
    } catch (e) {
      console.error(e);
    }
  };

  /**
   * Updates the status message displayed to the user.
   * @param {string} msg The new status message.
   */
  const updateStatus = (msg) => {
    status = msg;
  };

  /**
   * Updates the error message displayed to the user.
   * Prepends "Error: " to the message and sets it to null to clear it.
   * @param {string | null} msg The new error message.
   */
  const updateError = (msg) => {
    error = msg ? `Error: ${msg}` : null;
  };

  /**
   * Asynchronously starts the recording process. It requests microphone access,
   * sets up the Web Audio API graph to capture the input, and loads an
   * AudioWorklet to process the audio. The processed audio data (PCM) is then
   * sent in real-time to the Gemini session. It also handles UI state updates
   * and error management for the recording process.
   */
  const startRecording = async () => {
    // Prevent starting a new recording if one is already in progress.
    if (isRecording) {
      return;
    }

    // Resume the audio context. This is necessary in some browsers due to
    // autoplay policies that suspend the audio context until a user gesture.
    inputAudioContext.resume();

    updateStatus("Requesting microphone access...");

    try {

      // Prompt the user for microphone access and capture the live audio
      // stream if permission is granted.
      mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: true,
        video: false,
      });

      updateStatus("Microphone access granted. Starting capture...");

      // Create an audio source from the microphone stream and connect it
      // to the input gain node, which is the entry point for our audio
      // processing graph.
      sourceNode = inputAudioContext.createMediaStreamSource(mediaStream);
      sourceNode.connect(inputNode);

      // Load the custom audio processing script ('audio-processor.js') into a
      // separate, high-priority thread and create an AudioWorkletNode to run it.
      // This node is responsible for converting the raw audio into the PCM format
      // required by the Gemini API, without blocking the main UI thread.
      await inputAudioContext.audioWorklet.addModule("audio-processor.js");
      audioWorkletNode = new AudioWorkletNode(
        inputAudioContext,
        "audio-processor",
      );

      // This handler receives processed PCM audio data from the AudioWorklet.
      // It then creates a Blob from the data and sends it to the Gemini
      // session for real-time streaming recognition. This is the core of the
      // audio streaming pipeline.
      audioWorkletNode.port.onmessage = (event) => {
        if (!isRecording) return;
        const pcmData = event.data;
        session.sendRealtimeInput({ media: createBlob(pcmData) });
      };

      // Connect the microphone source to the audio worklet for processing.
      // The worklet must also be connected to the destination to keep the
      // audio graph alive and ensure its `process` method is called.
      sourceNode.connect(audioWorkletNode);
      audioWorkletNode.connect(inputAudioContext.destination);

      isRecording = true;
      updateStatus("🔴 Recording... Capturing PCM chunks.");
    } catch (err) {
      console.error("Error starting recording:", err);
      updateStatus(`Error: ${err.message}`);
      stopRecording();
    }
  };

  const stopRecording = () => {
    if (!isRecording && !mediaStream && !inputAudioContext) return;

    updateStatus("Stopping recording...");

    isRecording = false;

    // Disconnect the audio graph to stop processing and release resources.
    // This is a crucial cleanup step to prevent memory leaks and unnecessary
    // CPU usage from the audio processing thread.
    if (audioWorkletNode && sourceNode && inputAudioContext) {
      audioWorkletNode.disconnect();
      sourceNode.disconnect();
    }

    audioWorkletNode = null;
    sourceNode = null;

    // Stop all tracks in the media stream (i.e., the microphone) to release
    // the hardware and turn off the recording indicator. Then, nullify the
    // stream variable for cleanup.
    if (mediaStream) {
      mediaStream.getTracks().forEach((track) => track.stop());
      mediaStream = null;
    }

    updateStatus("Recording stopped. Click Start to begin again.");
  };

  const reset = () => {
    session?.close();
    initSession();
    updateStatus("Session cleared.");
  };
</script>

<div>
  <div class="controls">
    <button
      id="resetButton"
      onclick={reset}
      disabled={isRecording}
      aria-label="Reset Session"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        height="40px"
        viewBox="0 -960 960 960"
        width="40px"
        fill="#ffffff"
      >
        <path
          d="M480-160q-134 0-227-93t-93-227q0-134 93-227t227-93q69 0 132 28.5T720-690v-110h80v280H520v-80h168q-32-56-87.5-88T480-720q-100 0-170 70t-70 170q0 100 70 170t170 70q77 0 139-44t87-116h84q-28 106-114 173t-196 67Z"
        />
      </svg>
    </button>
    <button
      id="startButton"
      onclick={startRecording}
      disabled={isRecording}
      aria-label="Start Recording"
    >
      <svg
        viewBox="0 0 100 100"
        width="32px"
        height="32px"
        fill="#c80000"
        xmlns="http://www.w3.org/2000/svg"
      >
        <circle cx="50" cy="50" r="50" />
      </svg>
    </button>
    <button
      id="stopButton"
      onclick={stopRecording}
      disabled={!isRecording}
      aria-label="Stop Recording"
    >
      <svg
        viewBox="0 0 100 100"
        width="32px"
        height="32px"
        fill="#000000"
        xmlns="http://www.w3.org/2000/svg"
      >
        <rect x="0" y="0" width="100" height="100" rx="15" />
      </svg>
    </button>
  </div>

  <div id="status">{error || status}</div>
  <Visual3d {inputNode} {outputNode} />
</div>

<style>
  #status {
    position: absolute;
    bottom: 5vh;
    left: 0;
    right: 0;
    z-index: 10;
    text-align: center;
    color: #ffffff;
  }

  .controls {
    z-index: 10;
    position: absolute;
    bottom: 10vh;
    left: 0;
    right: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    gap: 10px;
  }

  button {
    outline: none;
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.1);
    width: 64px;
    height: 64px;
    cursor: pointer;
    font-size: 24px;
    padding: 0;
    margin: 0;
  }

  button:hover {
    background: rgba(255, 255, 255, 0.2);
  }

  button[disabled] {
    display: none;
  }
</style>
