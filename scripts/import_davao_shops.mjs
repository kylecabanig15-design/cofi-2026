import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Firebase Token Authentication
const tokensPath = path.join(process.env.HOME, '.config/configstore/firebase-tools.json');
const config = JSON.parse(fs.readFileSync(tokensPath, 'utf8'));
const token = config.tokens?.access_token;
const PROJECT_ID = 'cofi-3e5f4';

if (!token) {
  console.error('❌ Error: Firebase access token not found. Please log in with firebase login.');
  process.exit(1);
}

// Function to parse CSV line taking quotes into account
function parseCSV(text) {
  const lines = text.trim().split('\n');
  const headers = parseCSVLine(lines[0]);
  const rows = [];

  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = parseCSVLine(lines[i]);
    const row = {};
    headers.forEach((h, idx) => {
      row[h.trim()] = values[idx] !== undefined ? values[idx].trim() : '';
    });
    rows.push(row);
  }
  return rows;
}

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current);
  return result;
}

// Firestore REST Helper to format values
function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: val.toString() };
    return { doubleValue: val };
  }
  if (typeof val === 'string') return { stringValue: val };
  if (Array.isArray(val)) {
    return {
      arrayValue: {
        values: val.map(toFirestoreValue)
      }
    };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

async function importShops(csvFilePath, autoApprove = false) {
  console.log(`\n📂 Reading CSV file from: ${csvFilePath}`);
  const csvData = fs.readFileSync(csvFilePath, 'utf8');
  const rows = parseCSV(csvData);
  console.log(`📊 Found ${rows.length} shops in CSV.\n`);

  const status = autoApprove ? 'approved' : 'pending_approval';
  console.log(`🚀 Importing shops into Firestore ('shops' collection) with approvalStatus: '${status}'...\n`);

  let successCount = 0;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const shopName = row.name;

    // Parse boolean fields
    const wifi = row.wifi?.toUpperCase() === 'TRUE';
    const outlets = row.outlets?.toUpperCase() === 'TRUE';
    const parking = row.parking?.toUpperCase() === 'TRUE';
    const petFriendly = row.petFriendly?.toUpperCase() === 'TRUE';

    // Parse image URLs
    const logoUrl = row.logoUrl || null;
    const galleryUrls = row.galleryUrls ? row.galleryUrls.split(',').map(s => s.trim()).filter(Boolean) : [];

    // Parse drink types & tags
    const drinkTypes = row.drinkTypes ? row.drinkTypes.split(',').map(s => s.trim()).filter(Boolean) : [];
    const tags = [...drinkTypes];
    if (wifi) tags.push('Wi-Fi');
    if (outlets) tags.push('Power Outlets');
    if (parking) tags.push('Parking Available');
    if (petFriendly) tags.push('Pet Friendly');

    const defaultSchedule = {
      monday: { isOpen: true, open: '08:00', close: '22:00' },
      tuesday: { isOpen: true, open: '08:00', close: '22:00' },
      wednesday: { isOpen: true, open: '08:00', close: '22:00' },
      thursday: { isOpen: true, open: '08:00', close: '22:00' },
      friday: { isOpen: true, open: '08:00', close: '22:00' },
      saturday: { isOpen: true, open: '08:00', close: '22:00' },
      sunday: { isOpen: true, open: '08:00', close: '22:00' },
    };

    const documentData = {
      name: shopName,
      address: row.address || '',
      city: row.city || 'Davao City',
      about: row.about || '',
      latitude: parseFloat(row.latitude) || 0,
      longitude: parseFloat(row.longitude) || 0,
      priceLevel: row.priceLevel || '$$',
      hasWifi: wifi,
      hasOutlets: outlets,
      hasParking: parking,
      isPetFriendly: petFriendly,
      schedule: defaultSchedule,
      contacts: {
        instagram: row.instagram || '',
        facebook: row.facebook || '',
        tiktok: '',
        email: '',
        website: row.website || '',
        phone: row.phone || ''
      },
      logoUrl: logoUrl,
      gallery: galleryUrls,
      menuPricePhotos: [],
      tags: tags,
      postedBy: 'CSV Batch Import',
      posterId: 'admin_batch_import',
      postedAt: new Date().toISOString(),
      reviews: [],
      ratings: 0,
      ratingCount: 0,
      visits: [],
      menu: [],
      isVerified: autoApprove,
      submissionType: 'community',
      approvalStatus: status
    };

    // Format for Firestore REST API
    const fields = {};
    for (const [key, val] of Object.entries(documentData)) {
      if (key === 'postedAt') {
        fields[key] = { timestampValue: val };
      } else {
        fields[key] = toFirestoreValue(val);
      }
    }

    try {
      const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/shops`;
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ fields })
      });

      if (res.ok) {
        successCount++;
        console.log(`  [${i + 1}/${rows.length}] ✅ Successfully imported: "${shopName}"`);
      } else {
        const errText = await res.text();
        console.error(`  [${i + 1}/${rows.length}] ❌ Failed to import "${shopName}": ${errText}`);
      }
    } catch (e) {
      console.error(`  [${i + 1}/${rows.length}] ❌ Error importing "${shopName}": ${e.message}`);
    }
  }

  console.log(`\n🎉 Import Complete! ${successCount}/${rows.length} shops imported into Firestore.`);
  console.log(`📌 Approval Status set to: '${status}'`);
}

// Check command-line arguments
const csvPath = process.argv[2] || path.join(process.env.HOME, 'Downloads/CoFi_Davao_Coffee_Shops_20.csv');
const autoApprove = process.argv.includes('--approve');

importShops(csvPath, autoApprove);
