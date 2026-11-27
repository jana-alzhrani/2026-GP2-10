const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

exports.changeCourierPhone = onCall({ region: 'europe-west1' }, async (request) => {
    const callerUid = request.auth && request.auth.uid;
    if (!callerUid) {
        throw new HttpsError('unauthenticated', 'Sign in first.');
    }

    const db = admin.firestore();

    const caller = await db.collection('Users').doc(callerUid).get();
    if (!caller.exists || caller.get('role') !== 'admin') {
        throw new HttpsError('permission-denied', 'Admins only.');
    }

    const data = request.data || {};
    const userId = data.userId;
    const phone = data.phone;

    if (typeof userId !== 'string' || userId.length === 0) {
        throw new HttpsError('invalid-argument', 'Missing userId.');
    }

    if (typeof phone !== 'string' || !/^05\d{8}$/.test(phone)) {
        throw new HttpsError('invalid-argument', 'Invalid phone.');
    }

    const userRef = db.collection('Users').doc(userId);
    const user = await userRef.get();
    if (!user.exists || user.get('role') !== 'courier') {
        throw new HttpsError('not-found', 'Courier not found.');
    }

    const international = '+966' + phone.substring(1);

    const [localMatch, intlMatch, invite] = await Promise.all([
        db.collection('Users').where('phone', '==', phone).limit(2).get(),
        db.collection('Users').where('phone', '==', international).limit(2).get(),
        db.collection('couriers').doc(phone).get(),
    ]);

    const usedByOther = [...localMatch.docs, ...intlMatch.docs].some((d) => d.id !== userId);
    if (usedByOther || invite.exists) {
        throw new HttpsError('already-exists', 'Phone already in use.');
    }

    try {
        await admin.auth().updateUser(userId, { phoneNumber: international });
    } catch (e) {
        if (e.code === 'auth/phone-number-already-exists') {
            throw new HttpsError('already-exists', 'Phone already in use.');
        }
        if (e.code === 'auth/user-not-found') {
            throw new HttpsError('failed-precondition', 'Courier has no login account.');
        }
        throw new HttpsError('internal', 'Could not update phone.');
    }

    await userRef.update({ phone });

    return { ok: true };
});
