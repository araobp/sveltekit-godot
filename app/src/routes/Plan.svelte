<script lang="ts">

    const postLdContent = async (ldContent: string | null) => {
        if (!ldContent) {
            return;
        }

        const response = await fetch("/large_display", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ ld_content: ldContent }),
        });
        const result = await response.json();
        console.log(result);
    };
</script>

<div class="container mt-3">
    <select
        class="form-select form-select w-25"
        aria-label="Large display content"
        onchange={(e: Event) => {
            postLdContent((e.target as HTMLSelectElement).value);
        }}
    >
        <option value={null} selected>-- Large Display Content --</option>
        <option value="germany">Germany</option>
        <option value="germany2">Germany2</option>
    </select>
</div>
