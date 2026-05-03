/// Interruptores de funcionalidades do viewer (compile-time).
///
/// **Push (FCM):** com [kPushNotificationsEnabled] `false`, o app não inicializa
/// Firebase Messaging, não pede permissão de notificação nem regista token; também
/// não mostra telas/cards de envio de push (painel Academia e Admin global).
/// Para reativar, mude para `true` e faça rebuild.
const bool kPushNotificationsEnabled = true;
