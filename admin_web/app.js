const loginCard = document.getElementById("loginCard");
const adminPanel = document.getElementById("adminPanel");
const loginBtn = document.getElementById("loginBtn");
const loginError = document.getElementById("loginError");
const logoutBtn = document.getElementById("logoutBtn");
const adminWelcome = document.getElementById("adminWelcome");
const togglePasswordBtn = document.getElementById("togglePassword");
const loginPasswordInput = document.getElementById("loginPassword");
const loginEmailInput = document.getElementById("loginEmail");
const addTrainerBtn = document.getElementById("addTrainerBtn");
const trainerFormMessage = document.getElementById("trainerFormMessage");

const tabs = document.querySelectorAll("[data-tab]");
const criteriaTabs = document.querySelectorAll("[data-subtab]");
const assessedTabs = document.querySelectorAll("[data-assessed-subtab]");
const compModal = document.getElementById("compModal");
const compModalClose = document.getElementById("compModalClose");
const compModalCancel = document.getElementById("compModalCancel");
const compModalSave = document.getElementById("compModalSave");
const modalCompCategory = document.getElementById("modalCompCategory");
const modalCompTitle = document.getElementById("modalCompTitle");
const gradeModal = document.getElementById("gradeModal");
const gradeModalClose = document.getElementById("gradeModalClose");
const gradeModalCancel = document.getElementById("gradeModalCancel");
const gradeModalSave = document.getElementById("gradeModalSave");
const modalGradeCategory = document.getElementById("modalGradeCategory");
const modalGradeTitle = document.getElementById("modalGradeTitle");
const modalGradePercent = document.getElementById("modalGradePercent");
const modalGradeRange = document.getElementById("modalGradeRange");
const modalGradeRemark = document.getElementById("modalGradeRemark");
const usersTable = document.querySelector("#usersTable tbody");
const competencyTable = document.querySelector("#competencyTable tbody");
const assessmentTable = document.querySelector("#assessmentTable tbody");
const gradingTable = document.querySelector("#gradingTable tbody");
const auditTable = document.querySelector("#auditTable tbody");
const auditPrevBtn = document.getElementById("auditPrevBtn");
const auditNextBtn = document.getElementById("auditNextBtn");
const auditPageInfo = document.getElementById("auditPageInfo");
const auditModal = document.getElementById("auditModal");
const auditModalClose = document.getElementById("auditModalClose");
const auditModalCloseBtn = document.getElementById("auditModalCloseBtn");
const auditDetailTime = document.getElementById("auditDetailTime");
const auditDetailActor = document.getElementById("auditDetailActor");
const auditDetailAction = document.getElementById("auditDetailAction");
const auditDetailTarget = document.getElementById("auditDetailTarget");
const auditDetailDetails = document.getElementById("auditDetailDetails");
const batchStatusFilter = document.getElementById("batchStatusFilter");
const batchTrainerFilter = document.getElementById("batchTrainerFilter");
const refreshAssessedBtn = document.getElementById("refreshAssessedBtn");
const assessedBatchMessage = document.getElementById("assessedBatchMessage");
const assessedBatchesTable = document.querySelector("#assessedBatchesTable tbody");
const assessedOutputsTable = document.querySelector("#assessedOutputsTable tbody");
const selectedBatchSummary = document.getElementById("selectedBatchSummary");
const exportSelectedBatchBtn = document.getElementById("exportSelectedBatchBtn");
const assessedPrevBtn = document.getElementById("assessedPrevBtn");
const assessedNextBtn = document.getElementById("assessedNextBtn");
const assessedPageInfo = document.getElementById("assessedPageInfo");

let auditLogs = [];
let auditPage = 1;
const auditPageSize = 12;
let assessedBatches = [];
let selectedBatchId = null;
let assessedPage = 1;
const assessedPageSize = 8;
const memoryStorage = {};

const tokenKey = "admin_token";
const adminEmailKey = "admin_email";
const adminUsernameKey = "admin_username";

function safeSetItem(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch (error) {
    memoryStorage[key] = value;
  }
}

function safeGetItem(key) {
  try {
    return window.localStorage.getItem(key);
  } catch (error) {
    return Object.prototype.hasOwnProperty.call(memoryStorage, key)
      ? memoryStorage[key]
      : null;
  }
}

function safeRemoveItem(key) {
  try {
    window.localStorage.removeItem(key);
  } catch (error) {
    delete memoryStorage[key];
  }
}

function setAuth(token) {
  if (token) {
    safeSetItem(tokenKey, token);
  } else {
    safeRemoveItem(tokenKey);
    safeRemoveItem(adminEmailKey);
    safeRemoveItem(adminUsernameKey);
  }
}

function getAuth() {
  return safeGetItem(tokenKey);
}

function setAdminProfile(email, username) {
  if (email) safeSetItem(adminEmailKey, email);
  if (username) safeSetItem(adminUsernameKey, username);
}

function renderAdminProfile() {
  const email = safeGetItem(adminEmailKey) || "";
  const username = safeGetItem(adminUsernameKey) || "";
  const label = username || email;
  if (!label) {
    adminWelcome.classList.add("hidden");
    adminWelcome.textContent = "";
    return;
  }
  adminWelcome.textContent = `Logged in as ${label}`;
  adminWelcome.classList.remove("hidden");
}

async function apiPost(path, data = {}, auth = true) {
  const headers = { "Content-Type": "application/json" };
  if (auth) {
    const token = getAuth();
    if (token) headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(data),
  });
  const payload = await res.json();
  if (auth && payload.status === "error" && (payload.message === "Missing token." || payload.message === "Unauthorized.")) {
    setAuth(null);
    showAdminPanel(false);
  }
  return payload;
}

function showAdminPanel(show) {
  loginCard.classList.toggle("hidden", show);
  adminPanel.classList.toggle("hidden", !show);
  logoutBtn.classList.toggle("hidden", !show);
  if (show) {
    renderAdminProfile();
  } else {
    adminWelcome.classList.add("hidden");
    adminWelcome.textContent = "";
  }
}

tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    tabs.forEach((t) => t.classList.remove("active"));
    tab.classList.add("active");
    document.querySelectorAll("[id^='tab-']").forEach((el) => {
      el.classList.add("hidden");
    });
    document.getElementById(`tab-${tab.dataset.tab}`).classList.remove("hidden");
    if (tab.dataset.tab === "criteria") {
      document.getElementById("criteria-competency").classList.remove("hidden");
      document.getElementById("criteria-grading").classList.add("hidden");
      criteriaTabs.forEach((t) => t.classList.remove("active"));
      const first = document.querySelector("[data-subtab='competency']");
      if (first) first.classList.add("active");
    }
  });
});

criteriaTabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    criteriaTabs.forEach((t) => t.classList.remove("active"));
    tab.classList.add("active");
    document.getElementById("criteria-competency").classList.add("hidden");
    document.getElementById("criteria-assessment").classList.add("hidden");
    document.getElementById("criteria-grading").classList.add("hidden");
    if (tab.dataset.subtab === "competency") {
      document.getElementById("criteria-competency").classList.remove("hidden");
    } else if (tab.dataset.subtab === "assessment") {
      document.getElementById("criteria-assessment").classList.remove("hidden");
    } else {
      document.getElementById("criteria-grading").classList.remove("hidden");
    }
  });
});

assessedTabs.forEach((tab) => {
  tab.addEventListener("click", async () => {
    assessedTabs.forEach((t) => t.classList.remove("active"));
    tab.classList.add("active");
    const isBatchList = tab.dataset.assessedSubtab === "batch-list";
    document.getElementById("assessed-batch-list").classList.toggle("hidden", !isBatchList);
    document.getElementById("assessed-batch-detail").classList.toggle("hidden", isBatchList);
    if (isBatchList) {
      batchTrainerFilter.value = "";
      await loadAssessedWelding();
    }
  });
});

loginBtn.addEventListener("click", async () => {
  loginError.textContent = "";
  loginError.className = "muted";
  try {
    const email = loginEmailInput.value.trim();
    const password = document.getElementById("loginPassword").value;
    loginBtn.disabled = true;
    const data = await apiPost("/admin_login.php", { email, password }, false);
    loginBtn.disabled = false;
    if (data.status !== "success") {
      loginError.textContent = data.message || "Login failed.";
      loginError.className = "muted error-text";
      return;
    }
    setAuth(data.token);
    setAdminProfile(data.email || "", data.username || "");
    showAdminPanel(true);
    loginError.textContent = "";
    loadAll().catch((error) => {
      console.error("Admin page partial load failed:", error);
    });
  } catch (error) {
    loginBtn.disabled = false;
    console.error("Admin login flow failed:", error);
    loginError.textContent = "Unable to complete admin sign-in.";
    loginError.className = "muted error-text";
    showAdminPanel(false);
  }
});

[loginEmailInput, loginPasswordInput].forEach((input) => {
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      loginBtn.click();
    }
  });
});

togglePasswordBtn.addEventListener("click", () => {
  const isHidden = loginPasswordInput.type === "password";
  loginPasswordInput.type = isHidden ? "text" : "password";
  togglePasswordBtn.textContent = isHidden ? "Hide" : "Show";
});

logoutBtn.addEventListener("click", async () => {
  await apiPost("/admin_logout.php", {});
  setAuth(null);
  showAdminPanel(false);
});

function setFormMessage(node, message, type = "") {
  node.textContent = message;
  node.className = `muted${type === "success" ? " success-text" : ""}${type === "error" ? " error-text" : ""}`;
}

function buildTrainerPayload() {
  return {
    first_name: document.getElementById("trainerFirstName").value.trim(),
    middle_name: document.getElementById("trainerMiddleName").value.trim(),
    last_name: document.getElementById("trainerLastName").value.trim(),
    email: document.getElementById("trainerEmail").value.trim(),
    username: document.getElementById("trainerUsername").value.trim(),
    password: document.getElementById("trainerPassword").value,
    status: document.getElementById("trainerStatus").value,
  };
}

function resetTrainerForm() {
  document.getElementById("trainerFirstName").value = "";
  document.getElementById("trainerMiddleName").value = "";
  document.getElementById("trainerLastName").value = "";
  document.getElementById("trainerEmail").value = "";
  document.getElementById("trainerUsername").value = "";
  document.getElementById("trainerPassword").value = "";
  document.getElementById("trainerStatus").value = "active";
}

addTrainerBtn.addEventListener("click", async () => {
  setFormMessage(trainerFormMessage, "");
  const payload = buildTrainerPayload();
  const ok = window.confirm("Add this trainer account?");
  if (!ok) return;
  addTrainerBtn.disabled = true;
  const data = await apiPost("/admin_users.php", { action: "create", ...payload });
  addTrainerBtn.disabled = false;
  if (data.status !== "success") {
    setFormMessage(trainerFormMessage, data.message || "Unable to create trainer.", "error");
    return;
  }
  setFormMessage(trainerFormMessage, data.message || "Trainer created.", "success");
  resetTrainerForm();
  await loadUsers();
});

async function loadUsers() {
  usersTable.innerHTML = "";
  const data = await apiPost("/admin_users.php", { action: "list" });
  if (data.status !== "success") return;
  data.users.forEach((u) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${u.firstname} ${u.lastname}</td>
      <td>${u.email}</td>
      <td>
        <select data-id="${u.id}" data-field="role">
          <option value="admin" ${u.role === "admin" ? "selected" : ""}>admin</option>
          <option value="trainer" ${u.role === "trainer" ? "selected" : ""}>trainer</option>
        </select>
      </td>
      <td>
        <select data-id="${u.id}" data-field="status">
          <option value="active" ${u.status === "active" ? "selected" : ""}>active</option>
          <option value="inactive" ${u.status === "inactive" ? "selected" : ""}>inactive</option>
        </select>
      </td>
      <td>
        <select data-id="${u.id}" data-field="is_verified">
          <option value="1" ${u.is_verified == 1 ? "selected" : ""}>yes</option>
          <option value="0" ${u.is_verified == 0 ? "selected" : ""}>no</option>
        </select>
      </td>
      <td><button data-id="${u.id}" class="saveUserBtn">Save</button></td>
    `;
    usersTable.appendChild(tr);
  });

  document.querySelectorAll(".saveUserBtn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const ok = window.confirm("Save changes to this user?");
      if (!ok) return;
      const id = btn.dataset.id;
      const role = document.querySelector(`select[data-id="${id}"][data-field="role"]`).value;
      const status = document.querySelector(`select[data-id="${id}"][data-field="status"]`).value;
      const is_verified = document.querySelector(`select[data-id="${id}"][data-field="is_verified"]`).value;
      const result = await apiPost("/admin_users.php", {
        action: "update",
        user_id: id,
        role,
        status,
        is_verified: parseInt(is_verified, 10),
      });
      if (result.status !== "success") {
        window.alert(result.message || "Failed to update user.");
      }
    });
  });
}

function formatDateLabel(value) {
  if (!value) return "-";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleString();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function toAssetUrl(path) {
  if (!path) return "";
  if (/^https?:\/\//i.test(path)) return path;
  const base = API_BASE.replace(/\/+$/, "");
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${base}/demo_asset.php?path=${encodeURIComponent(normalizedPath)}`;
}

async function downloadWithAuth(path, filenameFallback) {
  const headers = {};
  const token = getAuth();
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${API_BASE}${path}`, {
    method: "GET",
    headers,
  });

  if (!response.ok) {
    let message = "Unable to export batch ZIP.";
    const contentType = response.headers.get("Content-Type") || "";
    if (contentType.includes("application/json")) {
      const payload = await response.json();
      message = payload.message || message;
    } else {
      const text = await response.text();
      if (text.trim()) message = text.trim();
    }
    throw new Error(message);
  }

  const blob = await response.blob();
  const objectUrl = window.URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = filenameFallback;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.URL.revokeObjectURL(objectUrl);
}

function renderSelectedBatch() {
  assessedOutputsTable.innerHTML = "";
  const batch = assessedBatches.find((item) => item.id === selectedBatchId);
  if (!batch) {
    selectedBatchSummary.textContent = "Select a batch to view its outputs.";
    exportSelectedBatchBtn.disabled = true;
    return;
  }

  exportSelectedBatchBtn.disabled = false;

  selectedBatchSummary.innerHTML = `
    <strong>${escapeHtml(batch.name)}</strong> | ${escapeHtml(formatTrainerLabel(batch))}
    | ${escapeHtml(batch.status)} | ${batch.assessed_count}/${batch.trainee_count} assessed
  `;

  batch.trainees.forEach((trainee) => {
    const tr = document.createElement("tr");
    const hasOriginal = Boolean(trainee.demo_image_url);
    const hasAnnotated = Boolean(trainee.demo_annotated_image_url);
    const demoStatus = String(trainee.demo_status || "pending").replace(/_/g, " ");
    tr.innerHTML = `
      <td>${escapeHtml(trainee.trainee_name)}</td>
      <td>${escapeHtml(trainee.training_center || "-")}</td>
      <td>${escapeHtml(trainee.status || "-")}</td>
      <td>${escapeHtml(trainee.result || "-")}</td>
      <td>${escapeHtml(trainee.assessed_date || "-")}</td>
      <td>
        <div>${escapeHtml(demoStatus)}</div>
        <div class="output-links" style="margin-top: 6px;">
          ${hasOriginal ? `<a class="output-link" href="${escapeHtml(toAssetUrl(trainee.demo_image_url))}" target="_blank" rel="noopener noreferrer">Original</a>` : ""}
          ${hasAnnotated ? `<a class="output-link" href="${escapeHtml(toAssetUrl(trainee.demo_annotated_image_url))}" target="_blank" rel="noopener noreferrer">Annotated</a>` : ""}
          ${!hasOriginal && !hasAnnotated ? `<span class="muted">No saved output</span>` : ""}
        </div>
      </td>
    `;
    assessedOutputsTable.appendChild(tr);
  });
}

function selectAssessedBatch(batchId) {
  selectedBatchId = batchId;
  assessedTabs.forEach((tab) => tab.classList.toggle("active", tab.dataset.assessedSubtab === "batch-detail"));
  document.getElementById("assessed-batch-list").classList.add("hidden");
  document.getElementById("assessed-batch-detail").classList.remove("hidden");
  renderSelectedBatch();
}

function formatTrainerLabel(batch) {
  const nameParts = [
    batch.trainer_firstname,
    batch.trainer_middlename,
    batch.trainer_lastname,
  ]
    .map((part) => String(part || "").trim())
    .filter(Boolean);
  const fullName = nameParts.join(" ");
  if (fullName && batch.trainer_email) {
    return `${fullName} (${batch.trainer_email})`;
  }
  return fullName || batch.trainer_email || batch.trainer_username || "-";
}

async function loadAssessedWelding() {
  assessedBatchMessage.textContent = "";
  assessedBatchesTable.innerHTML = "";
  const data = await apiPost("/admin_assessed_welding.php", {
    batch_status: batchStatusFilter.value,
    trainer_search: batchTrainerFilter.value.trim(),
  });
  if (data.status !== "success") {
    setFormMessage(assessedBatchMessage, data.message || "Unable to load assessed welding.", "error");
    return;
  }

  assessedBatches = Array.isArray(data.batches) ? data.batches : [];
  assessedPage = 1;
  if (!assessedBatches.length) {
    assessedBatchMessage.textContent = "No batches found for the current filters.";
    selectedBatchId = null;
    renderSelectedBatch();
    renderAssessedPage();
    return;
  }

  renderAssessedPage();

  if (selectedBatchId && assessedBatches.some((batch) => batch.id === selectedBatchId)) {
    renderSelectedBatch();
  } else {
    selectedBatchId = assessedBatches[0].id;
    renderSelectedBatch();
  }
}

function renderAssessedPage() {
  assessedBatchesTable.innerHTML = "";
  const totalPages = Math.max(1, Math.ceil(assessedBatches.length / assessedPageSize));
  if (assessedPage > totalPages) assessedPage = totalPages;
  const start = (assessedPage - 1) * assessedPageSize;
  const pageItems = assessedBatches.slice(start, start + assessedPageSize);

  pageItems.forEach((batch) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(batch.name)}</td>
      <td>${escapeHtml(formatTrainerLabel(batch))}</td>
      <td>${escapeHtml(batch.status)}</td>
      <td>${batch.trainee_count}</td>
      <td>${batch.assessed_count}</td>
      <td>${escapeHtml(formatDateLabel(batch.created_at))}</td>
      <td>
        <div class="action-stack">
          <button class="secondary viewBatchBtn" data-id="${batch.id}" type="button">View Outputs</button>
          <button class="secondary exportBatchBtn" data-id="${batch.id}" data-name="${escapeHtml(batch.name)}" type="button">Export ZIP</button>
        </div>
      </td>
    `;
    assessedBatchesTable.appendChild(tr);
  });

  document.querySelectorAll(".viewBatchBtn").forEach((btn) => {
    btn.addEventListener("click", () => {
      selectAssessedBatch(parseInt(btn.dataset.id, 10));
    });
  });

  document.querySelectorAll(".exportBatchBtn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const batchId = parseInt(btn.dataset.id, 10);
      const batchName = btn.dataset.name || "batch";
      try {
        await downloadWithAuth(
          `/admin_export_batch_weldings.php?batch_id=${encodeURIComponent(batchId)}`,
          `${batchName}_welding_outputs.zip`
        );
      } catch (error) {
        window.alert(error.message || "Unable to export batch ZIP.");
      }
    });
  });

  assessedPageInfo.textContent = `Page ${assessedPage} of ${totalPages}`;
  assessedPrevBtn.disabled = assessedPage <= 1;
  assessedNextBtn.disabled = assessedPage >= totalPages;
}

refreshAssessedBtn.addEventListener("click", async () => {
  await loadAssessedWelding();
});

assessedPrevBtn.addEventListener("click", () => {
  if (assessedPage > 1) {
    assessedPage -= 1;
    renderAssessedPage();
  }
});

assessedNextBtn.addEventListener("click", () => {
  const totalPages = Math.max(1, Math.ceil(assessedBatches.length / assessedPageSize));
  if (assessedPage < totalPages) {
    assessedPage += 1;
    renderAssessedPage();
  }
});

exportSelectedBatchBtn.addEventListener("click", async () => {
  if (!selectedBatchId) return;
  const batch = assessedBatches.find((item) => item.id === selectedBatchId);
  const batchName = batch?.name || "batch";
  try {
    await downloadWithAuth(
      `/admin_export_batch_weldings.php?batch_id=${encodeURIComponent(selectedBatchId)}`,
      `${batchName}_welding_outputs.zip`
    );
  } catch (error) {
    window.alert(error.message || "Unable to export batch ZIP.");
  }
});

async function safeLoadSection(loader, label) {
  try {
    await loader();
  } catch (error) {
    console.error(`Failed to load ${label}:`, error);
  }
}

async function loadCriteria() {
  competencyTable.innerHTML = "";
  assessmentTable.innerHTML = "";
  gradingTable.innerHTML = "";
  const data = await apiPost("/admin_criteria.php", { action: "list" });
  if (data.status !== "success") return;
  const compOrder = ["Basic", "Common", "Core"];
  const compByCategory = { Basic: [], Common: [], Core: [] };
  const assessmentOrder = [
    "Perform root pass",
    "Clean root pass",
    "Weld subsequent/filling passes",
    "Perform capping",
    "Defects (Surface Level)",
    "Defects (Non-Surface Level)",
  ];
  const assessmentByCategory = {
    "Perform root pass": [],
    "Clean root pass": [],
    "Weld subsequent/filling passes": [],
    "Perform capping": [],
    "Defects (Surface Level)": [],
    "Defects (Non-Surface Level)": [],
  };
  data.criteria
    .filter((c) => c.type === "competency" || c.type === "assessment")
    .forEach((c) => {
      if (c.type === "assessment") {
        if (!assessmentByCategory[c.category]) {
          assessmentByCategory[c.category] = [];
        }
        assessmentByCategory[c.category].push(c);
        return;
      }
      if (compByCategory[c.category]) {
        compByCategory[c.category].push(c);
      } else if (assessmentByCategory[c.category]) {
        assessmentByCategory[c.category].push(c);
      } else {
        compByCategory[c.category] = compByCategory[c.category] || [];
        compByCategory[c.category].push(c);
      }
    });

  compOrder.forEach((cat) => {
    const header = document.createElement("tr");
    header.classList.add("section-row");
    header.innerHTML = `
      <td class="cat-col"><span class="category-label">${cat}</span></td>
      <td class="title-col"></td>
      <td class="active-col"></td>
      <td class="action-col">
        <button class="addCompRowBtn" data-category="${cat}">Add Competency</button>
      </td>`;
    competencyTable.appendChild(header);
    (compByCategory[cat] || []).forEach((c) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td class="cat-col"><input data-id="${c.id}" data-field="category" value="${c.category || ""}" disabled /></td>
      <td class="title-col"><input data-id="${c.id}" data-field="title" value="${c.title || ""}" /></td>
      <td class="active-col">
        <select data-id="${c.id}" data-field="active">
          <option value="1" ${c.active == 1 ? "selected" : ""}>yes</option>
          <option value="0" ${c.active == 0 ? "selected" : ""}>no</option>
        </select>
      </td>
      <td class="action-col">
        <div class="action-inline">
          <button data-id="${c.id}" class="saveCriteriaBtn">Save</button>
          <button data-id="${c.id}" class="deleteCriteriaBtn secondary">Delete</button>
        </div>
      </td>
    `;
    competencyTable.appendChild(tr);
  });
  });

  assessmentOrder.forEach((cat) => {
    const header = document.createElement("tr");
    header.classList.add("section-row");
    header.innerHTML = `
      <td class="cat-col"><span class="category-label">${cat}</span></td>
      <td class="title-col"></td>
      <td class="active-col"></td>
      <td class="action-col">
        <button class="addCompRowBtn" data-category="${cat}">Add Criteria</button>
      </td>`;
    assessmentTable.appendChild(header);
    (assessmentByCategory[cat] || []).forEach((c) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td class="cat-col"><input data-id="${c.id}" data-field="category" value="${c.category || ""}" disabled /></td>
        <td class="title-col"><input data-id="${c.id}" data-field="title" value="${c.title || ""}" /></td>
        <td class="active-col">
          <select data-id="${c.id}" data-field="active">
            <option value="1" ${c.active == 1 ? "selected" : ""}>yes</option>
            <option value="0" ${c.active == 0 ? "selected" : ""}>no</option>
          </select>
        </td>
        <td class="action-col">
          <div class="action-inline">
            <button data-id="${c.id}" class="saveCriteriaBtn">Save</button>
            <button data-id="${c.id}" class="deleteCriteriaBtn secondary">Delete</button>
          </div>
        </td>
      `;
      assessmentTable.appendChild(tr);
    });
  });

  const gradeOrder = ["Grading", "Scale"];
  const gradeByCategory = { Grading: [], Scale: [] };
  data.criteria
    .filter((c) => c.type === "grading")
    .forEach((c) => {
      if (!gradeByCategory[c.category]) gradeByCategory[c.category] = [];
      gradeByCategory[c.category].push(c);
    });

  gradeOrder.forEach((cat) => {
    const header = document.createElement("tr");
    const btnLabel = cat === "Scale" ? "Add Scale Row" : "Add Grade Row";
    header.innerHTML = `
      <td class="title-col"><strong>${cat}</strong></td>
      <td class="percent-col"></td>
      <td class="range-col"></td>
      <td class="remark-col"></td>
      <td class="active-col"></td>
      <td class="action-col">
        <button class="addGradeRowBtn" data-category="${cat}">${btnLabel}</button>
      </td>`;
    gradingTable.appendChild(header);
    (gradeByCategory[cat] || []).forEach((c) => {
      const isScale = c.category === "Scale";
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td class="title-col">
          <input data-id="${c.id}" data-field="title" value="${c.title || ""}" />
        </td>
        <td class="percent-col">
          <input data-id="${c.id}" data-field="weight_percent" type="number" step="0.01" value="${c.weight_percent ?? ""}" ${isScale ? "disabled" : ""} />
        </td>
        <td class="range-col">
          <input data-id="${c.id}" data-field="scale_range" value="${c.scale_range || ""}" ${isScale ? "" : "disabled"} />
        </td>
        <td class="remark-col">
          ${
            isScale
              ? `<select data-id="${c.id}" data-field="remark">
                  <option value="Competent" ${c.remark === "Competent" ? "selected" : ""}>Competent</option>
                  <option value="Not yet Competent" ${c.remark === "Not yet Competent" ? "selected" : ""}>Not yet Competent</option>
                </select>`
              : `<input data-id="${c.id}" data-field="remark" value="${c.remark || ""}" disabled />`
          }
        </td>
        <td class="active-col">
          <select data-id="${c.id}" data-field="active">
            <option value="1" ${c.active == 1 ? "selected" : ""}>yes</option>
            <option value="0" ${c.active == 0 ? "selected" : ""}>no</option>
          </select>
        </td>
        <td class="action-col">
          <div class="action-inline">
            <button data-id="${c.id}" data-category="${c.category}" class="saveGradeBtn">Save</button>
            <button data-id="${c.id}" class="deleteGradeBtn secondary">Delete</button>
          </div>
        </td>
      `;
      gradingTable.appendChild(tr);
    });
  });

  document.querySelectorAll(".saveGradeBtn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const ok = window.confirm("Save changes to this item?");
      if (!ok) return;
      const id = btn.dataset.id;
      const title = document.querySelector(`input[data-id="${id}"][data-field="title"]`).value;
      const weightPercent = document.querySelector(`input[data-id="${id}"][data-field="weight_percent"]`).value;
      const scaleRange = document.querySelector(`input[data-id="${id}"][data-field="scale_range"]`).value;
      const remarkInput = document.querySelector(`[data-id="${id}"][data-field="remark"]`);
      const remark = remarkInput ? remarkInput.value : "";
      const active = document.querySelector(`select[data-id="${id}"][data-field="active"]`).value;
      const category = btn.dataset.category || "Grading";
      await apiPost("/admin_criteria.php", {
        action: "update",
        id,
        type: "grading",
        category,
        title,
        sort_order: 0,
        weight_percent: weightPercent,
        scale_range: scaleRange,
        remark,
        active: parseInt(active, 10),
      });
    });
  });

  document.querySelectorAll(".deleteGradeBtn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const ok = window.confirm("Delete this item? This cannot be undone.");
      if (!ok) return;
      const id = btn.dataset.id;
      await apiPost("/admin_criteria.php", { action: "delete", id });
      await loadCriteria();
    });
  });
}

  // Button handlers are delegated below.


function closeCompModal() {
  compModal.classList.add("hidden");
}

compModalClose.addEventListener("click", closeCompModal);
compModalCancel.addEventListener("click", closeCompModal);
compModal.addEventListener("click", (e) => {
  if (e.target === compModal) {
    closeCompModal();
  }
});

compModalSave.addEventListener("click", async () => {
  const category = modalCompCategory.value;
  const title = modalCompTitle.value.trim();
  if (!title) return;
  const activeTab = document.querySelector("[data-subtab].active");
  const type =
    activeTab && activeTab.dataset.subtab === "assessment" ? "assessment" : "competency";
  await apiPost("/admin_criteria.php", {
    action: "create",
    type,
    category,
    title,
    sort_order: 0,
    active: 1,
  });
  closeCompModal();
  await loadCriteria();
});

// Delegate clicks for dynamically rendered Add Competency buttons.
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".addCompRowBtn");
  if (!btn) return;
  const activeTab = document.querySelector("[data-subtab].active");
  const mode = activeTab && activeTab.dataset.subtab === "assessment" ? "assessment" : "competency";
  setCompCategoryOptions(mode);
  const cat = btn.dataset.category || (mode === "assessment" ? "Perform root pass" : "Basic");
  modalCompCategory.value = cat;
  modalCompTitle.value = "";
  compModal.classList.remove("hidden");
});

document.addEventListener("click", async (e) => {
  const saveBtn = e.target.closest(".saveCriteriaBtn");
  if (saveBtn) {
    const ok = window.confirm("Save changes to this item?");
    if (!ok) return;
    const id = saveBtn.dataset.id;
    const category = document.querySelector(`input[data-id="${id}"][data-field="category"]`).value;
    const title = document.querySelector(`input[data-id="${id}"][data-field="title"]`).value;
    const active = document.querySelector(`select[data-id="${id}"][data-field="active"]`).value;
    const activeTab = document.querySelector("[data-subtab].active");
    const type =
      activeTab && activeTab.dataset.subtab === "assessment" ? "assessment" : "competency";
    await apiPost("/admin_criteria.php", {
      action: "update",
      id,
      type,
      category,
      title,
      sort_order: 0,
      active: parseInt(active, 10),
    });
    return;
  }

  const deleteBtn = e.target.closest(".deleteCriteriaBtn");
  if (deleteBtn) {
    const ok = window.confirm("Delete this item? This cannot be undone.");
    if (!ok) return;
    const id = deleteBtn.dataset.id;
    await apiPost("/admin_criteria.php", { action: "delete", id });
    await loadCriteria();
  }
});

function closeGradeModal() {
  gradeModal.classList.add("hidden");
}

gradeModalClose.addEventListener("click", closeGradeModal);
gradeModalCancel.addEventListener("click", closeGradeModal);
gradeModal.addEventListener("click", (e) => {
  if (e.target === gradeModal) {
    closeGradeModal();
  }
});

gradeModalSave.addEventListener("click", async () => {
  const category = modalGradeCategory.value;
  const title = modalGradeTitle.value.trim();
  if (!title) return;
  const weightPercent = modalGradePercent.value;
  const scaleRange = modalGradeRange.value.trim();
  const remark = modalGradeRemark.value.trim();
  await apiPost("/admin_criteria.php", {
    action: "create",
    type: "grading",
    category,
    title,
    sort_order: 0,
    weight_percent: weightPercent,
    scale_range: scaleRange,
    remark,
    active: 1,
  });
  closeGradeModal();
  await loadCriteria();
});

// Delegate clicks for dynamically rendered Add Grade Row buttons.
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".addGradeRowBtn");
  if (!btn) return;
  const cat = btn.dataset.category || "Grading";
  modalGradeCategory.value = cat;
  modalGradeTitle.value = "";
  modalGradePercent.value = "";
  modalGradeRange.value = "";
  modalGradeRemark.value = "";
  const isScale = cat === "Scale";
  modalGradePercent.disabled = isScale;
  modalGradeRange.disabled = !isScale;
  modalGradeRemark.disabled = !isScale;
  gradeModal.classList.remove("hidden");
});

modalGradeCategory.addEventListener("change", () => {
  const isScale = modalGradeCategory.value === "Scale";
  modalGradePercent.disabled = isScale;
  modalGradeRange.disabled = !isScale;
  modalGradeRemark.disabled = !isScale;
});

async function loadAudit() {
  auditTable.innerHTML = "";
  const data = await apiPost("/admin_audit.php", { limit: 500 });
  if (data.status !== "success") return;
  auditLogs = Array.isArray(data.logs) ? data.logs : [];
  auditPage = 1;
  renderAuditPage();
}

function renderAuditPage() {
  auditTable.innerHTML = "";
  const totalPages = Math.max(1, Math.ceil(auditLogs.length / auditPageSize));
  if (auditPage > totalPages) auditPage = totalPages;
  const start = (auditPage - 1) * auditPageSize;
  const pageItems = auditLogs.slice(start, start + auditPageSize);

  pageItems.forEach((log) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${log.created_at}</td>
      <td>${log.actor_email || ""}</td>
      <td>${log.action}</td>
      <td>${log.target_type || ""} ${log.target_id || ""}</td>
      <td class="muted">${log.details || ""}</td>
      <td><button class="secondary viewAuditBtn">View detail</button></td>
    `;
    tr.querySelector(".viewAuditBtn").addEventListener("click", (e) => {
      e.stopPropagation();
      auditDetailTime.textContent = log.created_at || "-";
      auditDetailActor.textContent = log.actor_email || "-";
      auditDetailAction.textContent = log.action || "-";
      auditDetailTarget.textContent = `${log.target_type || ""} ${log.target_id || ""}`.trim() || "-";
      auditDetailDetails.textContent = log.details || "-";
      auditModal.classList.remove("hidden");
    });
    auditTable.appendChild(tr);
  });

  auditPageInfo.textContent = `Page ${auditPage} of ${totalPages}`;
  auditPrevBtn.disabled = auditPage <= 1;
  auditNextBtn.disabled = auditPage >= totalPages;
}

auditPrevBtn.addEventListener("click", () => {
  if (auditPage > 1) {
    auditPage -= 1;
    renderAuditPage();
  }
});

auditNextBtn.addEventListener("click", () => {
  const totalPages = Math.max(1, Math.ceil(auditLogs.length / auditPageSize));
  if (auditPage < totalPages) {
    auditPage += 1;
    renderAuditPage();
  }
});

function closeAuditModal() {
  auditModal.classList.add("hidden");
}

auditModalClose.addEventListener("click", closeAuditModal);
auditModalCloseBtn.addEventListener("click", closeAuditModal);
auditModal.addEventListener("click", (e) => {
  if (e.target === auditModal) {
    closeAuditModal();
  }
});

async function loadAll() {
  await safeLoadSection(loadUsers, "users");
  await safeLoadSection(loadAssessedWelding, "assessed welding");
  await safeLoadSection(loadCriteria, "criteria");
  await safeLoadSection(loadAudit, "audit");
}

if (getAuth()) {
  showAdminPanel(true);
  loadAll();
  const first = document.querySelector("[data-subtab='competency']");
  if (first) first.classList.add("active");
  document.getElementById("criteria-competency").classList.remove("hidden");
  document.getElementById("criteria-assessment").classList.add("hidden");
  document.getElementById("criteria-grading").classList.add("hidden");
  renderAdminProfile();
}
function setCompCategoryOptions(mode) {
  const options =
    mode === "assessment"
      ? [
          "Perform root pass",
          "Clean root pass",
          "Weld subsequent/filling passes",
          "Perform capping",
          "Defects (Surface Level)",
          "Defects (Non-Surface Level)",
        ]
      : ["Basic", "Common", "Core"];

  modalCompCategory.innerHTML = options
    .map((opt) => `<option value="${opt}">${opt}</option>`)
    .join("");
}
