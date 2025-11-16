<script lang="ts">
    import audioUrl from "$lib/assets/Bach,_BWV_147,_10._Jesus_bleibet_meine_Freude.ogg";
    import { onMount } from "svelte";

    let audio: HTMLAudioElement | null = null;
    let playing = $state(false);

    let ctx: AudioContext;
    let track: MediaElementAudioSourceNode;

    onMount(() => {
        ctx = new AudioContext();
        audio = new Audio(audioUrl);
        track = ctx.createMediaElementSource(audio);
    });
    
    const play = () => {
        if (ctx.state === "suspended") {
            ctx.resume();
        }
        track.connect(ctx.destination);
        if (audio) {
            audio.play();
        }
        playing = true;
    }

    const stop = () => {
        if (audio) {
            audio.pause();
        }
        playing = false;
    };

</script>

<h1>Web Audio API tests</h1>

<button
    onclick={() => {
        if (!playing) {
            play();
        } else {
            stop();
        }
    }}>{playing ? "Stop" : "Play"}</button
>