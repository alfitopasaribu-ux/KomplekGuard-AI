// Guardian Verify: a verification workflow, NOT a lie detector.
// Uses existing immutable ActivityLog records to avoid a production DB migration.
const PREFIX = 'GUARDIAN_VERIFY:';
const VALID_STATUSES = new Set(['BELUM_DIVERIFIKASI', 'PERLU_PEMERIKSAAN', 'TERVERIFIKASI', 'DITOLAK']);
const STAFF_ROLES = new Set(['ADMIN', 'KETUA_RT', 'SATPAM']);

function verificationAction(alertId) {
  return PREFIX + String(alertId);
}

function parseVerification(description) {
  try {
    const data = JSON.parse(description || '{}');
    return VALID_STATUSES.has(data.status) ? data.status : 'BELUM_DIVERIFIKASI';
  } catch (_) {
    return 'BELUM_DIVERIFIKASI';
  }
}

async function findVerificationMap(db, alertIds) {
  const ids = [...new Set(alertIds.map(String))].filter(Boolean);
  if (!ids.length) return new Map();
  const logs = await db.activityLog.findMany({
    where: { action: { in: ids.map(verificationAction) } },
    select: { action: true, description: true, createdAt: true },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  });
  const result = new Map();
  for (const log of logs) {
    const id = log.action.slice(PREFIX.length);
    if (!result.has(id)) result.set(id, {
      status: parseVerification(log.description),
      verifiedAt: log.createdAt,
    });
  }
  return result;
}

function verificationFor(alertId, byId) {
  return byId.get(String(alertId)) || {
    status: 'BELUM_DIVERIFIKASI',
    verifiedAt: null,
  };
}

// Sensitivity is intentionally conservative. New and private-assistance alerts
// never reveal precise coordinates to other residents, even if text is vague.
function isSensitiveAlert(alert) {
  const text = [alert.title, alert.description, alert.customCategory, alert.category?.name]
    .filter(Boolean).join(' ').toLowerCase();
  return /tolong|bantuan pribadi|ancam|serang|pencuri|pencurian|perampok|kekerasan|kekerasan seksual|pelecehan|penguntit|mencurigakan|hilang|rumah kosong|konflik|penculikan/i.test(text);
}

// Coordinates are rounded, not randomly shifted: map markers represent an
// approximate area, never a safe route or confirmed incident point.
function residentAlertView(alert, viewer, verification) {
  const owner = alert.userId === viewer.id;
  const privileged = STAFF_ROLES.has(viewer.role);
  const sensitive = isSensitiveAlert(alert);
  const approximate = !owner && !privileged &&
    (verification.status !== 'TERVERIFIKASI' || sensitive);
  const detail = { ...alert, verificationStatus: verification.status,
    verifiedAt: verification.verifiedAt, locationApproximate: approximate };
  if (!owner && !privileged) {
    if (detail.user) detail.user = {
      id: detail.user.id,
      name: sensitive ? 'Warga' : detail.user.name,
      role: detail.user.role,
    };
    if (Array.isArray(detail.responses)) {
      detail.responses = detail.responses.map(r => ({
        id: r.id, userId: r.userId, responseStatus: r.responseStatus,
        note: sensitive ? null : r.note, createdAt: r.createdAt,
        user: r.user ? { id: r.user.id, name: r.user.name, role: r.user.role } : null,
      }));
    }
    if (Array.isArray(detail.aiSummaries)) {
      detail.aiSummaries = detail.aiSummaries.map(({ rawAiResponse, ...rest }) => rest);
    }
    if (approximate) {
      const decimals = 2; // Coarse area on all unverified or sensitive reports.
      detail.latitude = Number(alert.latitude.toFixed(decimals));
      detail.longitude = Number(alert.longitude.toFixed(decimals));
      detail.address = 'Area perkiraan' +
        (alert.neighborhood?.name ? ' - ' + alert.neighborhood.name : '');
    }
    if (sensitive) {
      detail.title = 'Laporan bantuan atau keamanan pribadi';
      detail.description = 'Ada laporan warga yang memerlukan perhatian. ' +
        'Informasi sensitif hanya tersedia bagi petugas berwenang.';
      detail.photoUrl = null;
      detail.image = null;
      detail.aiSummary = null;
      detail.aiSummaries = [];
    }
  }
  return detail;
}

function reviewIndicators(alert, recentCount = 0) {
  const indicators = [];
  if ((alert.description || '').trim().length < 30) {
    indicators.push('Keterangan kejadian masih singkat; pertimbangkan klarifikasi.');
  }
  if (!alert.photoUrl && !alert.image) {
    indicators.push('Tidak ada foto pendukung; bukan berarti laporan palsu.');
  }
  if (recentCount >= 3) {
    indicators.push('Beberapa laporan dibuat dalam waktu berdekatan; periksa kemungkinan duplikasi.');
  }
  if (isSensitiveAlert(alert)) {
    indicators.push('Laporan sensitif: jangan arahkan warga ke titik tepat tanpa koordinasi petugas.');
  }
  return indicators;
}

module.exports = {
  PREFIX, STAFF_ROLES, VALID_STATUSES, verificationAction, parseVerification,
  findVerificationMap, verificationFor, residentAlertView, reviewIndicators,
  isSensitiveAlert,
};
