# DNS Setup & Domain Configuration

Deploying your URL shortener on the root domain `arogy.am` requires configuring DNS records at your DNS host (GoDaddy).

---

## 1. GoDaddy DNS Configuration

Log into your GoDaddy Control Panel, select your domain `arogy.am`, and add the following records:

| Type | Name | Value | TTL | Description |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `@` | `YOUR_VPS_PUBLIC_IPV4` | 1 Hour (or default) | Points root domain to the server |
| **AAAA** | `@` | `YOUR_VPS_PUBLIC_IPV6` | 1 Hour (or default) | Points root domain to the server (Optional, if IPv6 is available) |

*Note: The `@` symbol represents the root domain `arogy.am` itself.*

---

## 2. Automatic SSL/TLS Certificates (Let's Encrypt)

Because GoDaddy points your domain directly to your VPS IP address, Caddy handles everything automatically:
1. Caddy listens on ports `80` and `443`.
2. When the domain resolves to your server, Caddy contacts Let's Encrypt to solve the HTTP-01 challenge.
3. Let's Encrypt issues a secure SSL certificate for `arogy.am`.
4. Caddy auto-renews this certificate 30 days before expiration.

There are no manual steps or API keys required for SSL activation.

---

## 3. Preserving Visitor IPs for Analytics

Since your DNS records point directly to the VPS without intermediate CDN proxies (like Cloudflare):
1. **Direct connection**: Caddy receives the client connection directly from the visitor's TCP socket. The visitor's IP address is read directly.
2. **Caddy Header forwarding**: Caddy automatically sets standard headers (`X-Forwarded-For`, `X-Real-IP`) when proxying requests to the Shlink container.
3. **Shlink IP Restoration**: Shlink reads `X-Real-IP` and uses it to perform geo-location lookups (if MaxMind is enabled) and record click analytics.

Our Caddy and Shlink network settings automatically preserve visitor IPs without additional configuration.

---

## Appendix: Optional Cloudflare Integration (Alternative Setup)

If you decide to migrate your DNS management to Cloudflare in the future:
1. **SSL/TLS Mode**: Ensure the mode is set to **Full (strict)**. Never use *Flexible*, as it causes infinite redirect loops with Caddy's auto-redirects.
2. **Cache Bypass**: Create a Cloudflare Page Rule for `arogy.am/*` setting **Cache Level: Bypass** to prevent Cloudflare from caching redirect results (ensuring every click registers in your database analytics).
