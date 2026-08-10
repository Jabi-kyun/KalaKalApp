const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// ✅ Trigger automatically when a new listing is posted
exports.sendNewListingNotification = functions.firestore
  .document("listings/{listingId}")
  .onCreate(async (snap, context) => {
    const listingData = snap.data();
    
    // Safety check: ensure location exists
    if (!listingData.location || !listingData.location.latitude) {
      console.log("Listing missing location data.");
      return null;
    }

    const listingLat = listingData.location.latitude;
    const listingLng = listingData.location.longitude;

    // Fetch all collectors who have an FCM token
    const collectorsSnapshot = await admin.firestore()
      .collection("users")
      .where("role", "==", "collector")
      .where("fcmToken", "!=", null)
      .get();

    const promises = [];
    
    for (const doc of collectorsSnapshot.docs) {
      const collectorData = doc.data();
      const homeLoc = collectorData.homeLocation;
      
      // Skip if collector hasn't set their notification area yet
      if (!homeLoc || !homeLoc.latitude) continue;

      // ✅ Haversine Formula (Same math as your Flutter app)
      const R = 6371; // Earth's radius in km
      const dLat = (homeLoc.latitude - listingLat) * Math.PI / 180;
      const dLng = (homeLoc.longitude - listingLng) * Math.PI / 180;
      const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                Math.cos(listingLat * Math.PI / 180) * Math.cos(homeLoc.latitude * Math.PI / 180) *
                Math.sin(dLng/2) * Math.sin(dLng/2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
      const distanceKm = R * c;

      // ✅ Only notify if within 3km
      if (distanceKm <= 3.0) {
        const message = {
          token: collectorData.fcmToken,
          notification: {
            title: "New Scrap Nearby! ♻️",
            body: `${listingData.householdName} posted ${listingData.category} (${listingData.quantity}) just ${distanceKm.toFixed(1)}km away!`,
          },
          data: {
            listingId: context.params.listingId,
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          }
        };
        
        promises.push(admin.messaging().send(message));
      }
    }

    await Promise.all(promises);
    console.log(`Successfully sent notifications to nearby collectors.`);
    return null;
  });