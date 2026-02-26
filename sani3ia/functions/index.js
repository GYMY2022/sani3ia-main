const functions = require('firebase-functions');
const admin = require('firebase-admin');
const OneSignal = require('onesignal-node');

admin.initializeApp();

// إعدادات OneSignal - يجب تعيينها عبر متغيرات البيئة
const ONESIGNAL_APP_ID = functions.config().onesignal.app_id;
const ONESIGNAL_REST_API_KEY = functions.config().onesignal.rest_api_key;

const client = new OneSignal.Client(ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY);

// دالة مساعدة لجلب playerId للمستخدم
async function getUserPlayerId(userId) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  if (!userDoc.exists) return null;
  return userDoc.data().onesignalPlayerId || null;
}

// ========== 1. إشعار عند إضافة رسالة جديدة ==========
exports.onNewMessage = functions.firestore
  .document('{chatCollection}/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const receiverId = message.receiverId;
    const senderId = message.senderId;
    const senderName = message.senderName || 'مستخدم';
    const messageText = message.message || 'رسالة جديدة';
    const postId = message.postId;
    const chatType = context.params.chatCollection === 'market_chats' ? 'product' : 'job';

    if (!receiverId || receiverId === senderId) return null;

    const playerId = await getUserPlayerId(receiverId);
    if (!playerId) {
      console.log(`لا يوجد playerId للمستخدم ${receiverId}`);
      return null;
    }

    const notification = {
      contents: { 'en': senderName + ': ' + messageText },
      headings: { 'en': 'رسالة جديدة' },
      include_player_ids: [playerId],
      data: {
        screen: 'single-chat',
        receiverId: senderId,
        userName: senderName,
        postId: postId,
        chatType: chatType
      },
      android_channel_id: 'messages_channel',
    };

    try {
      const response = await client.createNotification(notification);
      console.log('✅ تم إرسال إشعار الرسالة:', response.body);
    } catch (error) {
      console.error('❌ فشل إرسال إشعار الرسالة:', error);
    }
  });

// ========== 2. إشعار عند إضافة إشعار في مجموعة notifications (اختياري) ==========
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    const userId = notif.userId;

    const playerId = await getUserPlayerId(userId);
    if (!playerId) return null;

    const notification = {
      contents: { 'en': notif.body },
      headings: { 'en': notif.title },
      include_player_ids: [playerId],
      data: {
        screen: notif.targetRoute,
        ...(notif.targetArguments || {})
      },
    };

    try {
      await client.createNotification(notification);
      console.log(`✅ تم إرسال إشعار للمستخدم ${userId}`);
    } catch (error) {
      console.error('❌ فشل إرسال إشعار:', error);
    }
  });

// ========== 3. (اختياري) دالة لإرسال إشعار مخصص عبر HTTP ==========
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  const { userId, title, body, payload } = data;
  if (!userId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'بيانات ناقصة');
  }

  const playerId = await getUserPlayerId(userId);
  if (!playerId) {
    throw new functions.https.HttpsError('not-found', 'لا يوجد playerId لهذا المستخدم');
  }

  const notification = {
    contents: { 'en': body },
    headings: { 'en': title },
    include_player_ids: [playerId],
    data: payload || {},
  };

  try {
    await client.createNotification(notification);
    return { success: true };
  } catch (error) {
    console.error(error);
    throw new functions.https.HttpsError('internal', 'فشل إرسال الإشعار');
  }
});