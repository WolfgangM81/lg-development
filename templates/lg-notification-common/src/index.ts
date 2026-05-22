/**
 * lg-notification-common - Shared notification utilities
 *
 * Main exports for email, SMS, and push notifications
 */

export { EmailService, type EmailOptions, type EmailTemplate } from './email/EmailService';
export { SMSService, type SMSOptions } from './sms/SMSService';
export { PushService, type PushOptions, type PushNotification } from './push/PushService';
export { NotificationQueue, type QueueConfig } from './queue/NotificationQueue';
export { NotificationTemplates } from './templates';
