/**
 * Email Service
 *
 * Handles email sending with template support
 */

import nodemailer, { Transporter } from 'nodemailer';
import Handlebars from 'handlebars';
import { readFileSync } from 'fs';
import { join } from 'path';

export interface EmailOptions {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  from?: string;
  cc?: string | string[];
  bcc?: string | string[];
  attachments?: Array<{
    filename: string;
    content: Buffer | string;
    contentType?: string;
  }>;
}

export interface EmailTemplate {
  name: string;
  subject: string;
  data: Record<string, any>;
}

export class EmailService {
  private transporter: Transporter;
  private defaultFrom: string;
  private templatesPath: string;

  constructor() {
    this.defaultFrom = process.env.EMAIL_FROM || 'noreply@licenseguard.com';
    this.templatesPath = process.env.EMAIL_TEMPLATES_PATH || join(__dirname, '../templates/email');

    this.transporter = nodemailer.createTransporter({
      host: process.env.SMTP_HOST || 'localhost',
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    });
  }

  /**
   * Send email
   */
  async sendEmail(options: EmailOptions): Promise<void> {
    await this.transporter.sendMail({
      from: options.from || this.defaultFrom,
      to: Array.isArray(options.to) ? options.to.join(', ') : options.to,
      cc: options.cc ? (Array.isArray(options.cc) ? options.cc.join(', ') : options.cc) : undefined,
      bcc: options.bcc ? (Array.isArray(options.bcc) ? options.bcc.join(', ') : options.bcc) : undefined,
      subject: options.subject,
      text: options.text,
      html: options.html,
      attachments: options.attachments
    });
  }

  /**
   * Send email using template
   */
  async sendTemplateEmail(to: string | string[], template: EmailTemplate): Promise<void> {
    const templatePath = join(this.templatesPath, `${template.name}.hbs`);
    const templateSource = readFileSync(templatePath, 'utf-8');
    const compiledTemplate = Handlebars.compile(templateSource);
    const html = compiledTemplate(template.data);

    await this.sendEmail({
      to,
      subject: template.subject,
      html
    });
  }

  /**
   * Verify SMTP connection
   */
  async verifyConnection(): Promise<boolean> {
    try {
      await this.transporter.verify();
      return true;
    } catch (error) {
      console.error('Email service connection failed:', error);
      return false;
    }
  }
}
