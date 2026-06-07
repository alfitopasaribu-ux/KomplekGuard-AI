const fs = require('fs');

const path = 'backend/app.js';
let text = fs.readFileSync(path, 'utf8');

if (!text.includes('async function reverseGeocodeAddress')) {
  const helper = `

async function reverseGeocodeAddress(lat, lng) {
  try {
    const url =
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2' +
      '&lat=' + encodeURIComponent(lat) +
      '&lon=' + encodeURIComponent(lng) +
      '&zoom=18&addressdetails=1';

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'KomplekGuardAI/1.0',
        'Accept': 'application/json',
      },
    });

    if (!response.ok) return null;

    const data = await response.json();
    const address = data && data.display_name ? String(data.display_name).trim() : '';

    return address || null;
  } catch (error) {
    console.error('Reverse geocode failed:', error.message);
    return null;
  }
}

async function enrichAlertAddress(req, res, next) {
  try {
    if (req.method === 'POST') {
      const lat = req.body.latitude;
      const lng = req.body.longitude;

      if (lat !== undefined && lng !== undefined && !req.body.address) {
        const address = await reverseGeocodeAddress(lat, lng);
        req.body.address = address || \`Koordinat: \${lat}, \${lng}\`;
      }
    }

    next();
  } catch (error) {
    next();
  }
}
`;

  text = text.replace('const app = express();', 'const app = express();' + helper);
}

if (!text.includes("app.use('/api/alerts', enrichAlertAddress);")) {
  text = text.replace(
    "app.use('/api/alerts', alertRoutes);",
    "app.use('/api/alerts', enrichAlertAddress);\napp.use('/api/alerts', alertRoutes);"
  );
}

fs.writeFileSync(path, text, 'utf8');
console.log('BERHASIL: backend/app.js ditambahkan auto address OpenStreetMap');
