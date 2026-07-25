import fs from 'fs';
import path from 'path';

// Firebase Token Authentication
const tokensPath = path.join(process.env.HOME, '.config/configstore/firebase-tools.json');
const config = JSON.parse(fs.readFileSync(tokensPath, 'utf8'));
const token = config.tokens?.access_token;
const PROJECT_ID = 'cofi-3e5f4';

if (!token) {
  console.error('❌ Error: Firebase access token not found. Please log in with firebase login.');
  process.exit(1);
}

// Helper to convert Firestore Value to JS Array
function fromFirestoreArray(firestoreVal) {
  if (!firestoreVal || !firestoreVal.arrayValue || !firestoreVal.arrayValue.values) return [];
  return firestoreVal.arrayValue.values.map(v => v.stringValue || v.integerValue || v.doubleValue || v.booleanValue);
}

// Helper to convert JS Array to Firestore Value
function toFirestoreArray(arr) {
  return {
    arrayValue: {
      values: arr.map(val => ({ stringValue: String(val) }))
    }
  };
}

async function cleanupPriceTags() {
  console.log('🔍 Fetching all shops to clean up price tags ($$)...');
  
  try {
    // 1. Fetch shops
    let url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/shops?pageSize=300`;
    let res = await fetch(url, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (!res.ok) {
      throw new Error(`Failed to fetch shops: ${await res.text()}`);
    }
    
    let data = await res.json();
    let documents = data.documents || [];
    
    console.log(`📊 Found ${documents.length} shops in Firestore.`);
    let updatedCount = 0;
    
    // 2. Iterate and update
    for (let doc of documents) {
      if (!doc.fields || !doc.fields.tags) continue;
      
      let tagsArray = fromFirestoreArray(doc.fields.tags);
      let originalLength = tagsArray.length;
      
      // Filter out price tags
      let cleanedTags = tagsArray.filter(tag => tag !== '$' && tag !== '$$' && tag !== '$$$');
      
      if (cleanedTags.length < originalLength) {
        // Needs update
        const docName = doc.name; // Full path e.g. projects/.../documents/shops/id
        const updateUrl = `https://firestore.googleapis.com/v1/${docName}?updateMask.fieldPaths=tags`;
        
        const updateRes = await fetch(updateUrl, {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            fields: {
              tags: toFirestoreArray(cleanedTags)
            }
          })
        });
        
        if (updateRes.ok) {
          console.log(`✅ Cleaned tags for shop: ${doc.fields.name?.stringValue || 'Unknown'}`);
          updatedCount++;
        } else {
          console.error(`❌ Failed to update shop ${doc.fields.name?.stringValue}: ${await updateRes.text()}`);
        }
      }
    }
    
    console.log(`\n🎉 Cleanup complete! Updated ${updatedCount} shops.`);
    
  } catch (e) {
    console.error('❌ Error during cleanup:', e);
  }
}

cleanupPriceTags();
