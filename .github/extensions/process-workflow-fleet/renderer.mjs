function serializeForInlineScript(value) {
    return JSON.stringify(value).replaceAll("<", "\\u003c");
}

export function renderDashboard(token) {
    return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Process workflow fleet</title>
  <style>
    :root {
      color-scheme: light dark;
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      background: var(--background-color-default, #ffffff);
      color: var(--text-color-default, #1f2328);
      font-family: var(--font-sans, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif);
      font-size: var(--text-body-medium, 14px);
      line-height: var(--leading-body-medium, 20px);
    }
    button,
    input,
    select {
      font: inherit;
    }
    button {
      border: 1px solid var(--border-color-default, #d0d7de);
      border-radius: 6px;
      padding: 6px 12px;
      background: var(--background-color-default, #ffffff);
      color: var(--text-color-default, #1f2328);
      cursor: pointer;
    }
    button:hover:not(:disabled) {
      background: var(--background-color-muted, #f6f8fa);
    }
    button:focus-visible,
    input:focus-visible,
    select:focus-visible {
      outline: 2px solid var(--color-focus-outline, #0969da);
      outline-offset: 2px;
    }
    button:disabled {
      cursor: not-allowed;
      opacity: 0.55;
    }
    .primary {
      border-color: var(--true-color-blue, #0969da);
      background: var(--true-color-blue, #0969da);
      color: var(--color-white, #ffffff);
    }
    .app {
      min-height: 100vh;
      display: grid;
      grid-template-rows: auto auto auto 1fr auto;
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 16px 20px;
      border-bottom: 1px solid var(--border-color-default, #d0d7de);
    }
    h1,
    h2,
    h3 {
      margin: 0;
      font-weight: var(--font-weight-semibold, 600);
    }
    h1 {
      font-size: var(--text-title-large, 26px);
      line-height: var(--leading-title-large, 32px);
    }
    h2 {
      font-size: var(--text-title-medium, 18px);
      line-height: var(--leading-title-medium, 24px);
    }
    h3 {
      font-size: var(--text-body-medium, 14px);
    }
    .muted {
      color: var(--text-color-muted, #656d76);
    }
    .status {
      padding: 10px 20px;
      border-bottom: 1px solid var(--border-color-default, #d0d7de);
    }
    .status[data-kind="error"] {
      background: var(--true-color-red-muted, #ffebe9);
      color: var(--true-color-red, #cf222e);
    }
    .status[data-kind="success"] {
      background: var(--true-color-blue-muted, #ddf4ff);
    }
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
      gap: 8px;
      padding: 12px 20px;
      border-bottom: 1px solid var(--border-color-default, #d0d7de);
    }
    .metric {
      border: 1px solid var(--border-color-default, #d0d7de);
      border-radius: 8px;
      padding: 10px 12px;
      background: var(--background-color-muted, #f6f8fa);
    }
    .metric strong {
      display: block;
      font-size: var(--text-title-medium, 18px);
    }
    .workspace {
      min-height: 0;
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(280px, 34%);
    }
    .fleet {
      min-width: 0;
      display: grid;
      grid-template-rows: auto minmax(0, 1fr);
      border-right: 1px solid var(--border-color-default, #d0d7de);
    }
    .toolbar {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      padding: 12px;
      border-bottom: 1px solid var(--border-color-default, #d0d7de);
    }
    .toolbar input {
      min-width: 220px;
      flex: 1;
    }
    input,
    select {
      border: 1px solid var(--border-color-default, #d0d7de);
      border-radius: 6px;
      padding: 6px 8px;
      background: var(--background-color-default, #ffffff);
      color: var(--text-color-default, #1f2328);
    }
    .table-wrap {
      overflow: auto;
    }
    table {
      width: 100%;
      min-width: 1500px;
      border-collapse: collapse;
    }
    th,
    td {
      padding: 8px;
      border-bottom: 1px solid var(--border-color-default, #d0d7de);
      text-align: left;
      vertical-align: top;
    }
    th {
      position: sticky;
      top: 0;
      z-index: 1;
      background: var(--background-color-muted, #f6f8fa);
      white-space: nowrap;
    }
    tbody tr {
      cursor: pointer;
    }
    tbody tr:hover,
    tbody tr[data-active="true"] {
      background: var(--background-color-muted, #f6f8fa);
    }
    code,
    pre {
      font-family: var(--font-mono, "SFMono-Regular", Consolas, monospace);
      font-size: var(--text-code-inline, 12px);
    }
    td code {
      white-space: pre-wrap;
      overflow-wrap: anywhere;
    }
    .badge {
      display: inline-block;
      border: 1px solid var(--border-color-default, #d0d7de);
      border-radius: 999px;
      padding: 1px 7px;
      white-space: nowrap;
    }
    .badge[data-status="compliant"] {
      border-color: var(--true-color-blue, #0969da);
    }
    .badge[data-status="parse-error"],
    .badge[data-status="incomplete"] {
      border-color: var(--true-color-red, #cf222e);
      color: var(--true-color-red, #cf222e);
    }
    aside {
      min-width: 0;
      overflow: auto;
      padding: 16px;
    }
    .detail-section {
      margin-top: 16px;
    }
    .delta {
      margin-top: 8px;
      padding: 10px;
      border: 1px solid var(--border-color-default, #d0d7de);
      border-radius: 8px;
    }
    .delta pre {
      margin: 6px 0 0;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      color: var(--text-color-muted, #656d76);
    }
    footer {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
      padding: 12px 20px;
      border-top: 1px solid var(--border-color-default, #d0d7de);
    }
    footer label {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-right: auto;
    }
    .empty {
      padding: 32px;
      text-align: center;
      color: var(--text-color-muted, #656d76);
    }
    @media (max-width: 900px) {
      .workspace {
        grid-template-columns: 1fr;
      }
      .fleet {
        border-right: 0;
      }
      aside {
        border-top: 1px solid var(--border-color-default, #d0d7de);
      }
    }
  </style>
</head>
<body>
  <div class="app">
    <header>
      <div>
        <h1>Process workflow fleet</h1>
        <div class="muted">Authenticated evidence and explicit v8 migration deltas</div>
      </div>
      <button class="primary" id="refresh">Refresh inventory</button>
    </header>
    <div class="status" id="status" role="status" aria-live="polite">Loading workspace state…</div>
    <section class="summary" id="summary" aria-label="Fleet summary"></section>
    <main class="workspace">
      <section class="fleet">
        <div class="toolbar">
          <input id="search" type="search" placeholder="Search repositories and workflow paths" aria-label="Search repositories">
          <select id="filter" aria-label="Filter by compliance status">
            <option value="">All statuses</option>
            <option value="compliant">Compliant</option>
            <option value="migration-needed">Migration needed</option>
            <option value="incomplete">Incomplete</option>
            <option value="parse-error">Parse error</option>
          </select>
          <button id="select-visible">Select visible</button>
          <button id="clear-selection">Clear selection</button>
        </div>
        <div class="table-wrap">
          <table aria-label="Process-PSModule caller workflow inventory">
            <thead>
              <tr>
                <th scope="col">Select</th>
                <th scope="col">Repository</th>
                <th scope="col">Workflow</th>
                <th scope="col">Reference / compliance</th>
                <th scope="col">Triggers</th>
                <th scope="col">Concurrency</th>
                <th scope="col">Permissions</th>
                <th scope="col">Condition</th>
                <th scope="col">Secrets</th>
                <th scope="col">Inputs</th>
                <th scope="col">Extra jobs</th>
              </tr>
            </thead>
            <tbody id="rows"></tbody>
          </table>
          <div class="empty" id="empty" hidden>No repositories match this view.</div>
        </div>
      </section>
      <aside id="inspector">
        <h2>Migration delta</h2>
        <p class="muted">Select a repository row to inspect its evidence and migration plan.</p>
      </aside>
    </main>
    <footer>
      <label>
        <input type="checkbox" id="confirm">
        I confirm Copilot may start one child session and draft PR per selected repository.
      </label>
      <button id="copy">Copy request</button>
      <button id="export">Export JSON</button>
      <button class="primary" id="request" disabled>Request migration</button>
    </footer>
  </div>
  <script>
    "use strict";
    const token = ${serializeForInlineScript(token)};
    const ui = {
      state: null,
      activeRepository: null,
      visible: [],
    };
    const byId = (id) => document.getElementById(id);
    const status = byId("status");

    function text(value) {
      if (value === null || value === undefined || value === "") return "—";
      if (Array.isArray(value)) return value.length ? value.join(", ") : "—";
      if (typeof value === "object") {
        const entries = Object.entries(value);
        return entries.length ? entries.map(([key, item]) => key + ":" + item).join(", ") : "{}";
      }
      return String(value);
    }

    function setStatus(message, kind = "info") {
      status.textContent = message;
      status.dataset.kind = kind;
    }

    async function api(path, options = {}) {
      const response = await fetch(path, {
        ...options,
        headers: {
          "Content-Type": "application/json",
          ...(options.method === "POST" ? { "X-Canvas-Token": token } : {}),
          ...(options.headers || {}),
        },
      });
      const payload = await response.json();
      if (!response.ok) {
        const error = new Error(payload.error?.message || "Canvas request failed.");
        error.code = payload.error?.code;
        throw error;
      }
      return payload;
    }

    function summaryMetric(label, value) {
      const element = document.createElement("div");
      element.className = "metric";
      const strong = document.createElement("strong");
      strong.textContent = String(value);
      const caption = document.createElement("span");
      caption.className = "muted";
      caption.textContent = label;
      element.append(strong, caption);
      return element;
    }

    function renderSummary() {
      const records = ui.state.records || [];
      const analyses = records.map((record) => record.analysis);
      const values = [
        ["Workflows", records.length],
        ["Compliant", analyses.filter((item) => item.compliant).length],
        ["Migration needed", analyses.filter((item) => item.status === "migration-needed").length],
        ["Incomplete", analyses.filter((item) => item.status === "incomplete").length],
        ["Parse errors", analyses.filter((item) => item.status === "parse-error").length],
        ["Selected", ui.state.selection.length],
      ];
      byId("summary").replaceChildren(...values.map(([label, value]) => summaryMetric(label, value)));
    }

    function codeCell(value) {
      const cell = document.createElement("td");
      const code = document.createElement("code");
      code.textContent = text(value);
      cell.append(code);
      return cell;
    }

    function repositoryCell(record) {
      const cell = document.createElement("td");
      const link = document.createElement(record.repositoryUrl ? "a" : "span");
      link.textContent = record.repository;
      if (record.repositoryUrl) {
        link.href = record.repositoryUrl;
        link.target = "_blank";
        link.rel = "noreferrer";
      }
      cell.append(link);
      if (record.archived) {
        const archived = document.createElement("div");
        archived.className = "muted";
        archived.textContent = "Archived";
        cell.append(archived);
      }
      return cell;
    }

    function workflowCell(record) {
      const cell = document.createElement("td");
      const path = document.createElement(record.workflowUrl ? "a" : "span");
      path.textContent = text(record.workflowPath);
      if (record.workflowUrl) {
        path.href = record.workflowUrl;
        path.target = "_blank";
        path.rel = "noreferrer";
      }
      const name = document.createElement("div");
      name.className = "muted";
      name.textContent = text(record.workflowName);
      cell.append(path, name);
      return cell;
    }

    function complianceCell(record) {
      const cell = document.createElement("td");
      const references = record.processJobs.map((job) => job.reference);
      const reference = document.createElement("code");
      reference.textContent = text(references);
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.dataset.status = record.analysis.status;
      badge.textContent = record.analysis.status;
      cell.append(reference, document.createElement("br"), badge);
      return cell;
    }

    function triggerText(record) {
      return [
        "events=" + text(record.events),
        "push=" + text(record.pushBranches),
        "pull_request=" + text(record.pullRequestBranches),
        "types=" + text(record.pullRequestTypes),
        "schedule=" + text(record.schedules),
      ].join("\\n");
    }

    function permissionText(record) {
      return [
        "workflow=" + text(record.permissions),
        ...record.processJobs.map((job) => "job=" + text(job.permissions)),
      ].join("\\n");
    }

    function jobValues(record, field) {
      return record.processJobs.map((job) => job[field]);
    }

    function createRow(record) {
      const row = document.createElement("tr");
      row.dataset.repository = record.repository;
      row.dataset.active = String(record.repository === ui.activeRepository);
      row.addEventListener("click", (event) => {
        if (event.target instanceof HTMLInputElement || event.target instanceof HTMLAnchorElement) return;
        ui.activeRepository = record.repository;
        renderRows();
        renderInspector(record);
      });
      const selectCell = document.createElement("td");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = ui.state.selection.includes(record.repository);
      checkbox.ariaLabel = "Select " + record.repository;
      checkbox.addEventListener("change", async () => {
        const next = new Set(ui.state.selection);
        checkbox.checked ? next.add(record.repository) : next.delete(record.repository);
        await updateSelection([...next]);
      });
      selectCell.append(checkbox);
      row.append(
        selectCell,
        repositoryCell(record),
        workflowCell(record),
        complianceCell(record),
        codeCell(triggerText(record)),
        codeCell("group=" + text(record.concurrencyGroup) + "\\ncancel=" + text(record.cancelInProgress)),
        codeCell(permissionText(record)),
        codeCell(jobValues(record, "condition")),
        codeCell(record.processJobs.map((job) => job.secretMode + ": " + text(job.secretMappings))),
        codeCell(record.processJobs.map((job) => job.inputs)),
        codeCell(record.additionalJobs),
      );
      return row;
    }

    function filteredRecords() {
      const query = byId("search").value.trim().toLowerCase();
      const filter = byId("filter").value;
      return (ui.state.records || []).filter((record) => {
        const matchesQuery = !query || [
          record.repository,
          record.workflowPath,
          record.workflowName,
          ...record.processJobs.map((job) => job.reference),
        ].some((value) => String(value || "").toLowerCase().includes(query));
        const matchesFilter = !filter || record.analysis.status === filter;
        return matchesQuery && matchesFilter;
      });
    }

    function renderRows() {
      ui.visible = filteredRecords();
      byId("rows").replaceChildren(...ui.visible.map(createRow));
      byId("empty").hidden = ui.visible.length > 0;
    }

    function detailBlock(title, value, instruction) {
      const block = document.createElement("div");
      block.className = "delta";
      const heading = document.createElement("h3");
      heading.textContent = title;
      const description = document.createElement("div");
      description.textContent = instruction;
      const pre = document.createElement("pre");
      pre.textContent = text(value);
      block.append(heading, description, pre);
      return block;
    }

    function detailSection(title, entries, mapping) {
      const section = document.createElement("section");
      section.className = "detail-section";
      const heading = document.createElement("h3");
      heading.textContent = title;
      section.append(heading);
      if (!entries.length) {
        const empty = document.createElement("p");
        empty.className = "muted";
        empty.textContent = "None.";
        section.append(empty);
      } else {
        section.append(...entries.map(mapping));
      }
      return section;
    }

    function renderInspector(record) {
      const inspector = byId("inspector");
      const heading = document.createElement("h2");
      heading.textContent = record.repository;
      const statusBadge = document.createElement("span");
      statusBadge.className = "badge";
      statusBadge.dataset.status = record.analysis.status;
      statusBadge.textContent = record.analysis.status;
      const path = document.createElement("p");
      path.className = "muted";
      path.textContent = text(record.workflowPath);
      const deltaSection = detailSection(
        "Required changes",
        record.analysis.deltas,
        (delta) => detailBlock(delta.field, { current: delta.current, target: delta.target }, delta.instruction),
      );
      const preserveSection = detailSection(
        "Preserve after verification",
        record.analysis.preservation,
        (item) => detailBlock(item.field, item.value, item.instruction),
      );
      const warningSection = detailSection(
        "Manual boundary review",
        record.analysis.reviewWarnings,
        (item) => detailBlock(item.field, item.value, item.instruction),
      );
      const missingSection = detailSection(
        "Missing inventory evidence",
        record.analysis.missingFields,
        (field) => detailBlock(field, "not captured", "Refresh with a compatible inventory script before requesting migration."),
      );
      inspector.replaceChildren(heading, statusBadge, path, deltaSection, preserveSection, warningSection, missingSection);
    }

    function renderState() {
      renderSummary();
      renderRows();
      byId("request").disabled = !byId("confirm").checked || ui.state.selection.length === 0 || ui.state.inventoryStatus !== "ready";
      if (ui.activeRepository) {
        const active = ui.state.records.find((record) => record.repository === ui.activeRepository);
        if (active) renderInspector(active);
      }
      if (ui.state.inventoryStatus === "failed") {
        setStatus("Refresh failed: " + text(ui.state.error?.message), "error");
      } else if (ui.state.inventoryStatus === "ready") {
        setStatus(
          "Inventory refreshed " + text(ui.state.generatedAt) + " from " + text(ui.state.organization) + ".",
          "success",
        );
      } else if (ui.state.inventoryStatus === "refreshing") {
        setStatus("Refreshing authenticated GitHub inventory…");
      } else {
        setStatus("No current inventory. Refresh to inspect the fleet.");
      }
    }

    async function loadState() {
      ui.state = await api("/api/state");
      renderState();
    }

    async function updateSelection(repositories) {
      try {
        const result = await api("/api/selection", {
          method: "POST",
          body: JSON.stringify({ repositories }),
        });
        ui.state.selection = result.repositories;
        renderState();
      } catch (error) {
        setStatus(error.message, "error");
        renderRows();
      }
    }

    async function previewRequest() {
      return api("/api/migration", {
        method: "POST",
        body: JSON.stringify({
          repositories: ui.state.selection,
          dryRun: true,
          confirmed: false,
        }),
      });
    }

    byId("refresh").addEventListener("click", async () => {
      byId("refresh").disabled = true;
      setStatus("Refreshing authenticated GitHub inventory…");
      try {
        await api("/api/refresh", {
          method: "POST",
          body: JSON.stringify({ organization: ui.state.organization || "PSModule" }),
        });
      } catch (error) {
        setStatus(error.message, "error");
      } finally {
        await loadState();
        byId("refresh").disabled = false;
      }
    });
    byId("search").addEventListener("input", renderRows);
    byId("filter").addEventListener("change", renderRows);
    byId("select-visible").addEventListener("click", () => updateSelection(ui.visible.map((record) => record.repository)));
    byId("clear-selection").addEventListener("click", () => updateSelection([]));
    byId("confirm").addEventListener("change", renderState);
    byId("copy").addEventListener("click", async () => {
      try {
        const preview = await previewRequest();
        await navigator.clipboard.writeText(preview.prompt);
        setStatus("Migration request copied to the clipboard.", "success");
      } catch (error) {
        setStatus(error.message, "error");
      }
    });
    byId("export").addEventListener("click", async () => {
      try {
        const preview = await previewRequest();
        const blob = new Blob([JSON.stringify(preview.request, null, 2) + "\\n"], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = "process-workflow-migration-request.json";
        link.click();
        URL.revokeObjectURL(url);
        setStatus("Structured migration request exported.", "success");
      } catch (error) {
        setStatus(error.message, "error");
      }
    });
    byId("request").addEventListener("click", async () => {
      if (!byId("confirm").checked) {
        setStatus("Confirm the repository-scoped child-session request first.", "error");
        return;
      }
      const confirmed = window.confirm(
        "Send this request to the active Copilot agent? It will orchestrate one child session, branch, and draft pull request per selected repository.",
      );
      if (!confirmed) return;
      byId("request").disabled = true;
      try {
        const result = await api("/api/migration", {
          method: "POST",
          body: JSON.stringify({
            repositories: ui.state.selection,
            dryRun: false,
            confirmed: true,
          }),
        });
        setStatus("Migration request sent to the active agent as message " + result.messageId + ".", "success");
      } catch (error) {
        setStatus(error.message, "error");
      } finally {
        renderState();
      }
    });

    loadState().catch((error) => setStatus(error.message, "error"));
  </script>
</body>
</html>`;
}
