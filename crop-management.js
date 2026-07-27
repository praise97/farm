const STORAGE_KEY = 'farmSmartPro.crops';
const API_BASE = window.location.protocol === 'file:' ? 'http://127.0.0.1:3000' : '';

const cropTypeConfig = {
  Maize: { icon: 'fa-wheat-awn', color: '#2d9b5e', idealDays: 120, moistureTarget: 62 },
  Tobacco: { icon: 'fa-leaf', color: '#2a7ab0', idealDays: 90, moistureTarget: 58 },
  Cotton: { icon: 'fa-seedling', color: '#d68a3c', idealDays: 150, moistureTarget: 54 },
  Tomatoes: { icon: 'fa-apple-whole', color: '#c73b3b', idealDays: 80, moistureTarget: 66 },
  Wheat: { icon: 'fa-wheat-awn-circle-exclamation', color: '#8c7b62', idealDays: 130, moistureTarget: 57 },
  Sorghum: { icon: 'fa-seedling', color: '#7d5a50', idealDays: 125, moistureTarget: 52 },
  Soybean: { icon: 'fa-spa', color: '#4c956c', idealDays: 110, moistureTarget: 60 },
  Groundnut: { icon: 'fa-pepper-hot', color: '#a44a3f', idealDays: 105, moistureTarget: 55 }
};

const refs = {
  currentDate: document.getElementById('currentDate'),
  refreshTime: document.getElementById('refreshTime'),
  addCropBtn: document.getElementById('addCropBtn'),
  cropModal: document.getElementById('cropModal'),
  closeModal: document.getElementById('closeModal'),
  cancelModalBtn: document.getElementById('cancelModalBtn'),
  cropForm: document.getElementById('cropForm'),
  cropList: document.getElementById('cropList'),
  overallPercent: document.getElementById('overallPercent'),
  plotCount: document.getElementById('plotCount'),
  plotChange: document.getElementById('plotChange'),
  avgMoisture: document.getElementById('avgMoisture'),
  moistureChange: document.getElementById('moistureChange'),
  alertCount: document.getElementById('alertCount'),
  alertsContainer: document.getElementById('alertsContainer'),
  soilInsightsList: document.getElementById('soilInsightsList'),
  pestInsightsList: document.getElementById('pestInsightsList'),
  soilActionCount: document.getElementById('soilActionCount'),
  pestAlertCount: document.getElementById('pestAlertCount')
};

let crops = [];
let apiAlerts = [];
let dashboardSummary = null;
let isApiMode = false;
let apiLookups = {
  fields: [],
  varieties: []
};

function formatDate(date) {
  return date.toLocaleDateString('en-ZW', {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  });
}

function formatDateTime(date) {
  return date.toLocaleString('en-ZW', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit'
  });
}

function formatYmd(dateValue) {
  if (!dateValue) {
    return '--';
  }
  return new Date(dateValue).toISOString().slice(0, 10);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function normalizeText(value) {
  return String(value || '').trim().toLowerCase();
}

function toApiUrl(path) {
  return `${API_BASE}${path}`;
}

async function fetchJson(path, init) {
  const response = await fetch(toApiUrl(path), init);
  if (!response.ok) {
    throw new Error(`${path} failed: ${response.status}`);
  }
  return response.json();
}

function populateLookupDatalists() {
  const fieldList = document.getElementById('fieldOptions');
  const varietyList = document.getElementById('varietyOptions');

  if (fieldList) {
    fieldList.innerHTML = apiLookups.fields
      .map((field) => `<option value="${field.field_name}"></option>`)
      .join('');
  }

  if (varietyList) {
    varietyList.innerHTML = apiLookups.varieties
      .map((variety) => `<option value="${variety.variety_name}"></option>`)
      .join('');
  }
}

function findFieldByName(fieldName) {
  const key = normalizeText(fieldName);
  return apiLookups.fields.find((field) => normalizeText(field.field_name) === key) || null;
}

function findVarietyByName(varietyName) {
  const key = normalizeText(varietyName);
  return apiLookups.varieties.find((variety) => normalizeText(variety.variety_name) === key) || null;
}

function bindLookupInteractions() {
  const varietyInput = document.getElementById('variety');
  const cropNameInput = document.getElementById('cropName');
  const cropTypeSelect = document.getElementById('cropType');

  if (!varietyInput || !cropNameInput || !cropTypeSelect) {
    return;
  }

  const syncCropFromVariety = () => {
    const selected = findVarietyByName(varietyInput.value);
    if (!selected) {
      return;
    }

    cropNameInput.value = selected.crop_name;
    cropTypeSelect.value = selected.crop_name;
  };

  varietyInput.addEventListener('change', syncCropFromVariety);
  varietyInput.addEventListener('blur', syncCropFromVariety);
}

async function loadApiLookups() {
  const [fields, varieties] = await Promise.all([
    fetchJson('/api/fields'),
    fetchJson('/api/varieties')
  ]);

  apiLookups = {
    fields: Array.isArray(fields) ? fields : [],
    varieties: Array.isArray(varieties) ? varieties : []
  };

  populateLookupDatalists();
}

function loadCropsFromStorage() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      crops = [];
      return;
    }
    const parsed = JSON.parse(raw);
    crops = Array.isArray(parsed) ? parsed : [];
  } catch {
    crops = [];
  }
}

function saveCropsToStorage() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(crops));
}

function daysSince(dateStr) {
  const planted = new Date(dateStr);
  const now = new Date();
  const diff = now.getTime() - planted.getTime();
  return Math.max(0, Math.floor(diff / (1000 * 60 * 60 * 24)));
}

function growthPercent(crop) {
  if (crop.growthPercent != null) {
    return clamp(Number(crop.growthPercent), 0, 100);
  }
  const cfg = cropTypeConfig[crop.cropType] || { idealDays: 120 };
  const age = daysSince(crop.plantingDate);
  return clamp(Math.round((age / cfg.idealDays) * 100), 1, 100);
}

function deterministicNoise(seedText, spread) {
  let hash = 0;
  for (let i = 0; i < seedText.length; i += 1) {
    hash = (hash * 31 + seedText.charCodeAt(i)) >>> 0;
  }
  return (hash % (spread * 2 + 1)) - spread;
}

function estimatedMoisture(crop) {
  if (crop.moisturePercent != null && !Number.isNaN(Number(crop.moisturePercent))) {
    return clamp(Math.round(Number(crop.moisturePercent)), 0, 100);
  }
  const cfg = cropTypeConfig[crop.cropType] || { moistureTarget: 58 };
  const age = daysSince(crop.plantingDate);
  const seasonalDrift = Math.floor(age / 15);
  const noise = deterministicNoise(String(crop.id), 4);
  return clamp(cfg.moistureTarget - seasonalDrift + noise, 34, 78);
}

function estimatedHealth(crop) {
  const growth = growthPercent(crop);
  const moisture = estimatedMoisture(crop);
  const moisturePenalty = Math.abs(60 - moisture);
  return clamp(Math.round(growth - moisturePenalty / 2 + 18), 25, 98);
}

function normalizeActiveCrop(row) {
  return {
    id: String(row.planting_id),
    plantingId: row.planting_id,
    cropName: row.crop_name,
    variety: row.variety_name,
    cropType: row.crop_name,
    fieldName: row.field_name,
    plantingDate: formatYmd(row.planting_date),
    growthPercent: row.growth_percent,
    growthStage: row.growth_stage,
    moisturePercent: row.latest_moisture_percent,
    latestPestPresence: row.latest_pest_presence,
    latestDiseasePresence: row.latest_disease_presence
  };
}

function iconForCrop(cropType) {
  const cfg = cropTypeConfig[cropType] || cropTypeConfig.Maize;
  return { icon: cfg.icon, color: cfg.color };
}

function renderCropList() {
  const overallCard = refs.cropList.querySelector('#overallCrop');
  refs.cropList.innerHTML = '';
  if (overallCard) {
    refs.cropList.appendChild(overallCard);
  }

  if (crops.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'crop-item';
    empty.innerHTML = `
      <div class="icon"><i class="fas fa-seedling"></i></div>
      <div class="info">
        <div class="name">No crops available</div>
        <div class="detail">${isApiMode ? 'No active plantings returned by the API.' : 'Click "Add Crop" to start tracking your fields.'}</div>
      </div>
    `;
    refs.cropList.appendChild(empty);
    refs.overallPercent.textContent = '0%';
    const fill = refs.cropList.querySelector('#overallCrop .fill');
    if (fill) {
      fill.style.width = '0%';
    }
    return;
  }

  let healthTotal = 0;

  crops.forEach((crop) => {
    const visual = iconForCrop(crop.cropType);
    const growth = growthPercent(crop);
    const moisture = estimatedMoisture(crop);
    const health = estimatedHealth(crop);
    healthTotal += health;

    const row = document.createElement('div');
    row.className = 'crop-item';
    row.innerHTML = `
      <div class="icon" style="background: ${visual.color}1A; color: ${visual.color};">
        <i class="fas ${visual.icon}"></i>
      </div>
      <div class="info">
        <div class="name">${crop.cropName}${crop.variety ? ` (${crop.variety})` : ''}</div>
        <div class="detail">${crop.cropType}${crop.fieldName ? ` - ${crop.fieldName}` : ''}${crop.growthStage ? ` - ${crop.growthStage}` : ''}</div>
        <div class="meta">
          <span><i class="far fa-calendar"></i> ${crop.plantingDate}</span>
          <span><i class="fas fa-tint"></i> ${moisture}% moisture</span>
        </div>
      </div>
      <div class="progress-wrap">
        <div class="progress-bar"><div class="fill" style="width: ${growth}%; background: ${visual.color};"></div></div>
        <span class="progress-label">${growth}%</span>
      </div>
      ${isApiMode ? '' : `<button class="delete-btn" data-id="${crop.id}" aria-label="Delete crop"><i class="fas fa-trash"></i></button>`}
    `;

    refs.cropList.appendChild(row);
  });

  const overall = Math.round(healthTotal / crops.length);
  refs.overallPercent.textContent = `${overall}%`;
  const fill = refs.cropList.querySelector('#overallCrop .fill');
  if (fill) {
    fill.style.width = `${overall}%`;
  }
}

function iconForLevel(level) {
  if (level === 'danger') {
    return 'fa-triangle-exclamation';
  }
  if (level === 'warning') {
    return 'fa-circle-exclamation';
  }
  if (level === 'green') {
    return 'fa-check-circle';
  }
  return 'fa-info-circle';
}

function renderAlertCollection(container, items) {
  container.innerHTML = '';
  items.forEach((item) => {
    const row = document.createElement('div');
    row.className = container.id === 'alertsContainer' ? 'alert-item' : 'insight-item';
    row.innerHTML = `
      <div class="icon ${item.level}"><i class="fas ${iconForLevel(item.level)}"></i></div>
      <div class="content">
        <div class="title">${item.title}</div>
        <div class="desc">${item.desc}</div>
        <div class="meta"><i class="far fa-clock"></i> ${item.timeLabel || formatDateTime(new Date())}</div>
      </div>
    `;

    if (container.id === 'alertsContainer') {
      const timeNode = row.querySelector('.meta');
      if (timeNode) {
        timeNode.className = 'time';
      }
    }

    container.appendChild(row);
  });
}

function buildAlertsFromApi() {
  if (!apiAlerts.length) {
    return [{
      level: 'info',
      title: 'No active alerts',
      desc: 'No pest or disease alerts from the API.',
      timeLabel: 'Live'
    }];
  }

  return apiAlerts.map((alert) => {
    const status = (alert.alert_status || '').toLowerCase();
    const level = status.includes('disease') || status.includes('pest and disease') ? 'danger' : 'warning';
    return {
      level,
      title: `${alert.crop_name} (${alert.field_name})`,
      desc: alert.alert_status,
      timeLabel: alert.last_observation ? formatDateTime(new Date(alert.last_observation)) : 'Live'
    };
  });
}

function buildInsightsFromApi() {
  const soilInsights = [];
  const pestInsights = [];

  crops.forEach((crop) => {
    const moisture = estimatedMoisture(crop);
    if (moisture < 45) {
      soilInsights.push({
        level: 'warning',
        title: `${crop.cropName}: Low soil moisture`,
        desc: `${crop.fieldName || 'Field'} at ${moisture}% moisture. Irrigation recommended.`
      });
    }
    if (moisture >= 45 && moisture <= 70) {
      soilInsights.push({
        level: 'green',
        title: `${crop.cropName}: Soil moisture stable`,
        desc: `${crop.fieldName || 'Field'} currently in healthy range (${moisture}%).`
      });
    }
  });

  apiAlerts.forEach((alert) => {
    const status = (alert.alert_status || '').toLowerCase();
    const isPest = status.includes('pest');
    const isDisease = status.includes('disease');

    if (isPest || isDisease) {
      pestInsights.push({
        level: isDisease ? 'danger' : 'warning',
        title: `${alert.crop_name}: ${alert.alert_status}`,
        desc: `Field ${alert.field_name} requires scouting and follow-up action.`
      });
    }
  });

  if (!soilInsights.length) {
    soilInsights.push({
      level: crops.length ? 'green' : 'info',
      title: crops.length ? 'Soil indicators in healthy range' : 'No soil alerts',
      desc: crops.length ? 'No moisture stress signals in latest API sync.' : 'Add moisture data to enable soil alerts.'
    });
  }

  if (!pestInsights.length) {
    pestInsights.push({
      level: 'info',
      title: crops.length ? 'No major pest threats flagged' : 'No pest alerts',
      desc: crops.length ? 'No pest or disease issues from recent observations.' : 'Add observations to enable pest alerts.'
    });
  }

  return { soilInsights, pestInsights };
}

function renderStatsAndInsights() {
  const plotCount = crops.length;
  refs.plotCount.textContent = String(plotCount);
  refs.plotChange.innerHTML = `<i class="fas fa-arrow-up"></i> ${plotCount} tracked this season`;

  if (isApiMode && dashboardSummary) {
    const avg = dashboardSummary.avg_soil_moisture;
    if (avg == null) {
      refs.avgMoisture.innerHTML = '--<span class="unit">%</span>';
      refs.moistureChange.className = 'change negative';
      refs.moistureChange.innerHTML = '<i class="fas fa-arrow-down"></i> No sensor data yet';
    } else {
      refs.avgMoisture.innerHTML = `${Math.round(Number(avg))}<span class="unit">%</span>`;
      refs.moistureChange.className = 'change positive';
      refs.moistureChange.innerHTML = '<i class="fas fa-arrow-up"></i> Live from sensor readings';
    }

    const smartAlerts = dashboardSummary.smart_alerts ?? apiAlerts.length;
    refs.alertCount.textContent = String(smartAlerts);

    const alerts = buildAlertsFromApi();
    const insights = buildInsightsFromApi();
    refs.soilActionCount.textContent = `${insights.soilInsights.length} actions`;
    refs.pestAlertCount.textContent = String(insights.pestInsights.length);

    renderAlertCollection(refs.alertsContainer, alerts);
    renderAlertCollection(refs.soilInsightsList, insights.soilInsights);
    renderAlertCollection(refs.pestInsightsList, insights.pestInsights);
    return;
  }

  if (plotCount === 0) {
    refs.avgMoisture.innerHTML = '--<span class="unit">%</span>';
    refs.moistureChange.className = 'change negative';
    refs.moistureChange.innerHTML = '<i class="fas fa-arrow-down"></i> 0% from yesterday';
  } else {
    const moistureValues = crops.map(estimatedMoisture);
    const avg = Math.round(moistureValues.reduce((sum, n) => sum + n, 0) / moistureValues.length);
    refs.avgMoisture.innerHTML = `${avg}<span class="unit">%</span>`;
    const change = clamp(60 - avg, -12, 12);
    if (change <= 0) {
      refs.moistureChange.className = 'change positive';
      refs.moistureChange.innerHTML = `<i class="fas fa-arrow-up"></i> ${Math.abs(change)}% from yesterday`;
    } else {
      refs.moistureChange.className = 'change negative';
      refs.moistureChange.innerHTML = `<i class="fas fa-arrow-down"></i> ${Math.abs(change)}% from yesterday`;
    }
  }

  const localAlerts = [];
  const soilInsights = [];
  const pestInsights = [];

  crops.forEach((crop) => {
    const moisture = estimatedMoisture(crop);
    const growth = growthPercent(crop);
    const days = daysSince(crop.plantingDate);

    if (moisture < 45) {
      localAlerts.push({
        level: 'warning',
        title: `Low soil moisture in ${crop.cropName}`,
        desc: `${crop.fieldName || crop.cropType} is at ${moisture}% moisture. Schedule irrigation today.`
      });
      soilInsights.push({
        level: 'warning',
        title: `${crop.cropName}: Moisture below target`,
        desc: `Current ${moisture}% vs target near ${(cropTypeConfig[crop.cropType] || { moistureTarget: 58 }).moistureTarget}%`
      });
    }

    if (days > 70 && growth < 55) {
      localAlerts.push({
        level: 'danger',
        title: `Growth lag detected for ${crop.cropName}`,
        desc: `Growth is ${growth}% after ${days} days. Check nutrients and pest pressure.`
      });
    }
  });

  if (!localAlerts.length) {
    localAlerts.push({
      level: 'info',
      title: crops.length ? 'All monitored plots are stable' : 'No active alerts',
      desc: crops.length ? 'No urgent crop issues detected in the latest local scan.' : 'Add crops to receive personalized alerts.'
    });
  }

  if (!soilInsights.length) {
    soilInsights.push({
      level: crops.length ? 'green' : 'info',
      title: crops.length ? 'Soil indicators in healthy range' : 'No soil alerts',
      desc: crops.length ? 'Continue current watering strategy and monitor every 48 hours.' : 'Add crops to get personalized recommendations.'
    });
  }

  if (!pestInsights.length) {
    pestInsights.push({
      level: 'info',
      title: crops.length ? 'No major pest threats flagged' : 'No pest alerts',
      desc: crops.length ? 'Keep scouting routine active to maintain early detection.' : 'Your crops are currently safe.'
    });
  }

  refs.alertCount.textContent = String(localAlerts.length);
  refs.soilActionCount.textContent = `${soilInsights.length} actions`;
  refs.pestAlertCount.textContent = String(pestInsights.length);

  renderAlertCollection(refs.alertsContainer, localAlerts);
  renderAlertCollection(refs.soilInsightsList, soilInsights);
  renderAlertCollection(refs.pestInsightsList, pestInsights);
}

function refreshUI() {
  renderCropList();
  renderStatsAndInsights();
  refs.refreshTime.textContent = formatDateTime(new Date());
}

async function loadDashboardFromApi() {
  const [summary, active, alerts] = await Promise.all([
    fetchJson('/api/dashboard/summary'),
    fetchJson('/api/crops/active'),
    fetchJson('/api/alerts')
  ]);

  dashboardSummary = summary;
  crops = Array.isArray(active) ? active.map(normalizeActiveCrop) : [];
  apiAlerts = Array.isArray(alerts) ? alerts : [];
  isApiMode = true;
}

async function syncDashboardData() {
  try {
    await loadApiLookups();
    await loadDashboardFromApi();
  } catch {
    isApiMode = false;
    dashboardSummary = null;
    apiAlerts = [];
    loadCropsFromStorage();
  }

  refreshUI();
}

function openModal() {
  refs.cropModal.classList.add('active');
}

function closeModal() {
  refs.cropModal.classList.remove('active');
  refs.cropForm.reset();
}

async function addCropFromForm(event) {
  event.preventDefault();

  const cropName = document.getElementById('cropName').value.trim();
  const variety = document.getElementById('variety').value.trim();
  const cropType = document.getElementById('cropType').value;
  const plantingDate = document.getElementById('plantingDate').value;
  const fieldName = document.getElementById('fieldName').value.trim();
  const notes = document.getElementById('notes').value.trim();

  if (isApiMode) {
    const selectedField = findFieldByName(fieldName);
    const selectedVariety = findVarietyByName(variety);

    if (!selectedField) {
      alert('Please choose a valid Field / Plot Name from the lookup list.');
      return;
    }

    if (!selectedVariety) {
      alert('Please choose a valid Variety from the lookup list.');
      return;
    }

    if (!plantingDate) {
      alert('Planting date is required.');
      return;
    }

    try {
      await fetchJson('/api/plantings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          field_id: selectedField.field_id,
          variety_id: selectedVariety.variety_id,
          planting_date: plantingDate,
          crop_type: selectedVariety.crop_name,
          notes: notes || null
        })
      });

      closeModal();
      await syncDashboardData();
    } catch {
      alert('Failed to create planting via API. Confirm the API and database are running.');
    }

    return;
  }

  if (!cropName || !cropType || !plantingDate) {
    return;
  }

  const crop = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`,
    cropName,
    variety,
    cropType,
    plantingDate,
    fieldName,
    notes,
    createdAt: new Date().toISOString()
  };

  crops.unshift(crop);
  saveCropsToStorage();
  refreshUI();
  closeModal();
}

function handleDelete(event) {
  if (isApiMode) {
    return;
  }

  const button = event.target.closest('.delete-btn');
  if (!button) {
    return;
  }

  const { id } = button.dataset;
  crops = crops.filter((crop) => crop.id !== id);
  saveCropsToStorage();
  refreshUI();
}

function wireLinks() {
  const noopLinks = [
    document.getElementById('manageCropsLink'),
    document.getElementById('viewAlertsLink'),
    document.getElementById('viewAllCropsLink'),
    document.getElementById('viewAllAlertsLink')
  ].filter(Boolean);

  noopLinks.forEach((link) => {
    link.addEventListener('click', (event) => {
      event.preventDefault();
    });
  });
}

function initDates() {
  const now = new Date();
  refs.currentDate.textContent = formatDate(now);
  refs.refreshTime.textContent = formatDateTime(now);
}

async function init() {
  initDates();
  wireLinks();
  bindLookupInteractions();

  refs.addCropBtn.addEventListener('click', openModal);
  refs.closeModal.addEventListener('click', closeModal);
  refs.cancelModalBtn.addEventListener('click', closeModal);
  refs.cropModal.addEventListener('click', (event) => {
    if (event.target === refs.cropModal) {
      closeModal();
    }
  });
  refs.cropForm.addEventListener('submit', addCropFromForm);
  refs.cropList.addEventListener('click', handleDelete);

  await syncDashboardData();
  setInterval(() => {
    syncDashboardData();
  }, 60000);
}

init();
