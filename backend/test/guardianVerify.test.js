const test = require('node:test');
const assert = require('node:assert/strict');
const {
  verificationFor, parseVerification, residentAlertView,
  reviewIndicators, isSensitiveAlert,
} = require('../src/utils/guardianVerify');

const sample = {
  id: 'a1', userId: 'reporter', title: 'Tolong saya di rumah kosong',
  description: 'Saya butuh pertolongan, lokasi rumah kosong',
  latitude: -8.654321, longitude: 115.234567,
  address: 'Alamat tepat dan nomor rumah', photoUrl: 'data:image/png;base64,AA',
  aiSummary: 'Informasi pribadi', category: { name: 'Keamanan' },
  user: { id: 'reporter', name: 'Nama Lengkap', email: 'private@example.test', phone: '123', address: 'Rumah' },
  responses: [{ id: 'r', userId: 'helper', responseStatus: 'MEMBANTU',
    createdAt: new Date(), note: 'Informasi', user: { id: 'helper', name: 'Penolong', phone: '123', role: 'WARGA' } }],
  aiSummaries: [{ summary: 'Rahasia', rawAiResponse: 'rahasia' }],
};

test('cold start defaults to unverified', () => {
  assert.equal(verificationFor('new', new Map()).status, 'BELUM_DIVERIFIKASI');
  assert.equal(parseVerification('not json'), 'BELUM_DIVERIFIKASI');
  assert.equal(parseVerification(JSON.stringify({ status: 'PENJAHAT' })), 'BELUM_DIVERIFIKASI');
});

test('sensitive first report hides exact location, PII, photos and description', () => {
  const data = residentAlertView(sample, { id: 'other', role: 'WARGA' },
    { status: 'BELUM_DIVERIFIKASI' });
  assert.equal(data.locationApproximate, true);
  assert.equal(data.latitude, -8.65);
  assert.equal(data.longitude, 115.23);
  assert.equal(data.address.includes('nomor rumah'), false);
  assert.equal(data.user.phone, undefined);
  assert.equal(data.user.email, undefined);
  assert.equal(data.photoUrl, null);
  assert.equal(data.description.includes('rumah kosong'), false);
  assert.equal(data.aiSummaries[0], undefined);
  assert.equal(data.responses[0].user.phone, undefined);
});

test('original reporter sees own incident without exposing it to everyone', () => {
  const data = residentAlertView(sample, { id: 'reporter', role: 'WARGA' },
    { status: 'BELUM_DIVERIFIKASI' });
  assert.equal(data.locationApproximate, false);
  assert.equal(data.latitude, sample.latitude);
});

test('even verified sensitive reports hide details from the public', () => {
  const data = residentAlertView(sample, { id: 'other', role: 'WARGA' },
    { status: 'TERVERIFIKASI' });
  assert.equal(data.locationApproximate, true);
});

test('ordinary unverified incident has approximate location but readable summary', () => {
  const alert = { ...sample, title: 'Pohon tumbang dekat jalan',
    description: 'Pohon tumbang menutup jalan besar.', photoUrl: null };
  const data = residentAlertView(alert, { id: 'other', role: 'WARGA' },
    { status: 'BELUM_DIVERIFIKASI' });
  assert.equal(isSensitiveAlert(alert), false);
  assert.equal(data.locationApproximate, true);
  assert.equal(data.description, alert.description);
  assert.ok(reviewIndicators(alert).some(x => x.includes('foto')));
});
