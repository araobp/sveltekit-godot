<div class="container mt-3" style="height: 100vh;">
    <ul class="nav nav-tabs" id="myTab" role="tablist">
        <li class="nav-item" role="presentation">
            <button
                class="nav-link active"
                id="plan-tab"
                data-bs-toggle="tab"
                data-bs-target="#plan-tab-pane"
                type="button"
                role="tab"
                aria-controls="plan-tab-pane"
                aria-selected="true">Plan</button
            >
        </li>
        <li class="nav-item" role="presentation">
            <button
                class="nav-link"
                id="simulation-tab"
                data-bs-toggle="tab"
                data-bs-target="#simulation-tab-pane"
                type="button"
                role="tab"
                aria-controls="simulation-tab-pane"
                aria-selected="false">Simulation</button
            >
        </li>
    </ul>

    <div class="tab-content h-100" id="myTabContent">
        <div
            class="tab-pane fade show active"
            id="plan-tab-pane"
            role="tabpanel"
            aria-labelledby="plan-tab"
            tabindex="0"
        >
            ...
        </div>
        <div
            class="tab-pane one"
            style="height: 90%;"
            id="simulation-tab-pane"
            role="tabpanel"
            aria-labelledby="simulation-tab"
            tabindex="0"
        >
            <iframe style="width: 100%; height: 100%;" src="/godot.html"> </iframe>
        </div>
    </div>
</div>
