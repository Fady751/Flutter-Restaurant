/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

// Trigger when a new notification is created
exports.sendBookingNotification = onDocumentCreated(
  "vendor_notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const notificationData = snapshot.data();

    // Get all vendor FCM tokens
    const db = getFirestore();
    const tokensSnapshot = await db.collection("vendor_fcm_tokens").get();

    if (tokensSnapshot.empty) {
      console.log("No vendor tokens found");
      return;
    }

    const tokens = [];
    tokensSnapshot.forEach((doc) => {
      const token = doc.data().token;
      if (token) {
        tokens.push(token);
      }
    });

    if (tokens.length === 0) {
      console.log("No valid tokens");
      return;
    }

    // Create the notification message
    const message = {
      notification: {
        title: "New Table Booking!",
        body: `${notificationData.customerName || "A customer"} booked a table at ${notificationData.restaurantName || "your restaurant"}`,
      },
      data: {
        restaurantId: notificationData.restaurantId || "",
        restaurantName: notificationData.restaurantName || "",
        tableId: notificationData.tableId || "",
        date: notificationData.date || "",
        timeSlot: notificationData.timeSlot || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    // Send to all vendor devices
    const messaging = getMessaging();
    const response = await messaging.sendEachForMulticast({
      tokens: tokens,
      ...message,
    });

    console.log(`Successfully sent ${response.successCount} messages`);
    if (response.failureCount > 0) {
      console.log(`Failed to send ${response.failureCount} messages`);
    }

    return null;
  }
);
