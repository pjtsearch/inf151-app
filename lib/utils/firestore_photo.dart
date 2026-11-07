/// Leaves headroom under Firestore's 1 MiB document limit after base64 encoding.
const maxFirestorePhotoBytes = 650 * 1024;
