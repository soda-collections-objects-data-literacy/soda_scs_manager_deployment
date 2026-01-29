# Configuring Nextcloud email

Nextcloud requires email configuration to send notifications, password resets, and user registration emails.

## Accessing email settings

1. Log in to Nextcloud as admin
2. Go to **Settings** → **Administration** → **Basic settings**
3. Scroll to **Email server** section

## Email modes

### SMTP (recommended)

Use an external SMTP server (Gmail, Mailgun, SendGrid, your organization's mail server).

**Settings:**
- **Server address:** SMTP server hostname (e.g., `smtp.gmail.com`)
- **Port:** Usually `587` (STARTTLS) or `465` (SSL/TLS)
- **Encryption:** `STARTTLS` or `SSL/TLS` (recommended)
- **Requires authentication:** Check this
- **Server address:** May need to repeat the SMTP hostname
- **Credentials:** Username and password for SMTP authentication
- **From address:** Email address to use as sender (e.g., `nextcloud@yourdomain.com`)

**Example (Gmail):**
- Server: `smtp.gmail.com`
- Port: `587`
- Encryption: `STARTTLS`
- Authentication: Yes
- Username: Your Gmail address
- Password: App-specific password (not your regular password if 2FA is enabled)
- From: Your Gmail address

**Example (Mailgun):**
- Server: `smtp.mailgun.org`
- Port: `587`
- Encryption: `STARTTLS`
- Authentication: Yes
- Username: Your Mailgun SMTP username (from Mailgun dashboard)
- Password: Your Mailgun SMTP password
- From: `noreply@yourdomain.com` (must be a verified domain in Mailgun)

### Sendmail

Use the local system's `sendmail` binary. Requires a properly configured mail server on the host.

**Settings:**
- Select **Sendmail** mode
- Ensure the host has `sendmail` or compatible MTA (Postfix, Exim) configured

**Note:** This mode is less reliable in containerized environments unless the host MTA is properly configured.

### PHP mail()

Uses PHP's built-in `mail()` function. Generally not recommended as it has limited configuration options and is prone to delivery issues.

## Testing email

After configuring:

1. Enter a test recipient email in the **Send email** field
2. Click **Send email**
3. Check the recipient's inbox (and spam folder)
4. If delivery fails, check Nextcloud logs (Settings → Administration → Logging) for SMTP errors

## Common issues

### Authentication fails

**Symptom:** "SMTP authentication failed" or "Invalid credentials"

**Fixes:**
- Verify username and password are correct
- For Gmail: Use an [app-specific password](https://support.google.com/accounts/answer/185833)
- For Office 365/Outlook: May need to enable SMTP AUTH for the account
- Check if the SMTP server requires a full email address or just the local part as username

### Connection timeout or refused

**Symptom:** "Connection refused" or "Connection timed out"

**Fixes:**
- Verify server address and port are correct
- Check firewall rules allow outbound connections on the SMTP port
- Try a different port (587 vs 465)
- Check if encryption setting matches the port (587 = STARTTLS, 465 = SSL/TLS)

### Emails not received

**Symptom:** Test email succeeds but no email arrives

**Fixes:**
- Check spam/junk folder
- Verify the "From" address is valid and not blacklisted
- Check Nextcloud logs for delivery errors
- For transactional email services (Mailgun, SendGrid), check their dashboard for delivery logs

### SSL certificate verification fails

**Symptom:** "SSL certificate problem: unable to get local issuer certificate"

**Fixes:**
- Ensure the Nextcloud container has up-to-date CA certificates
- For self-signed certificates, you may need to disable certificate verification (not recommended for production)

## Environment variables (recommended)

You can configure email via environment variables in `.env`, which are applied automatically during post-installation or by running the configuration script.

Add to `.env`:

```bash
NEXTCLOUD_NEXTCLOUD_MAIL_MODE=smtp
NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_HOST=smtp.example.com
NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PORT=587
NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_SECURE=tls
NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_AUTH=1
NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_USERNAME=your-username
NEXTCLOUD_NEXTCLOUD_MAIL_SMTP_PASSWORD=your-password
NEXTCLOUD_NEXTCLOUD_MAIL_FROM_ADDRESS=noreply
NEXTCLOUD_NEXTCLOUD_MAIL_DOMAIN=yourdomain.com
```

**Apply to new install:**
- Add variables to `.env` before first start
- Run `docker compose up -d nextcloud--nextcloud`
- Post-installation hook will configure email automatically

**Apply to existing install:**
```bash
01_scripts/scs-nextcloud-stack/configure-nextcloud-email.bash
```

Settings configured via environment variables can still be overridden in the Nextcloud admin UI.

## Using a local relay (advanced)

If you have many services that send email, consider setting up a local mail relay (Postfix) on the host or in a container:

1. Configure Postfix as a relay to your SMTP provider
2. Point Nextcloud SMTP to `localhost:25` (or the relay container)
3. All services use the relay, which handles authentication and delivery

This centralizes email configuration and makes it easier to switch providers.

## Security considerations

- **Never commit SMTP passwords** to version control. Use `.env` or secrets management.
- **Use app-specific passwords** for personal email accounts with 2FA.
- **Use a dedicated sending address** (e.g., `noreply@`) instead of personal addresses.
- **SPF/DKIM/DMARC:** If using a custom domain, configure these DNS records to improve deliverability.

## Verification after configuration

After configuring email:

1. **Test with admin account:** Send test email to yourself
2. **Test user registration:** Create a new user (if self-registration is enabled) and verify they receive the welcome email
3. **Test password reset:** Use "Forgot password" feature to verify reset emails work
4. **Test sharing notifications:** Share a file with another user and verify they receive a notification email

## Further reading

- [Nextcloud Email Configuration Documentation](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/email_configuration.html)
- [Gmail SMTP settings](https://support.google.com/mail/answer/7126229)
- [Office 365 SMTP settings](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365)
