# Branding, Customization, & UI Options

This document details options for branding and customizing Shlink, covering short URL redirects, slug styles, custom domains, and custom web client branding.

---

## 1. Supported Branding Options (Out-of-the-Box)

Shlink supports several native customization features via environment variables and CLI parameters.

### 1.1 Custom Domains & Multi-Domain Support
Shlink supports managing multiple domains from a single instance:
- **Default Domain**: Configured in `.env` under `SHLINK_DOMAIN` (e.g. `arogy.am`).
- **Additional Domains**: You can add secondary short domains (e.g., `links.example.com`, `promo.net`) using the Shlink CLI:
  ```bash
  docker exec -it shlink-engine shlink domain:add links.example.com
  ```
  URLs generated under secondary domains will use their respective base URLs while sharing the same database.

### 1.2 Custom URL Slugs
When creating short links, Shlink supports three slug generation strategies:
- **Random short codes**: Generated automatically. You can configure the character set and default length (e.g., 5 characters) via environment variables.
- **Readable campaign names**: You can define custom slugs during link creation (e.g., `https://arogy.am/blackfriday` or `https://arogy.am/summer-sale`).

### 1.3 Custom Fallback Redirects (404 & Index Pages)
You can brand the destinations for invalid traffic:
- **Base URL Redirect**: Redirects users who visit the root domain (`https://arogy.am/`) directly. Typically points to your main company website.
- **Regular 404 Redirect**: Redirects users who visit a non-existent short URL.
- **Invalid Short URL Redirect**: Redirects users who request a slug that does not match the character format requirements.

Configure these in `.env`:
```ini
SHLINK_DEFAULT_DOMAIN_REDIRECT=https://mycompany.com
SHLINK_REGULAR_404_REDIRECT=https://mycompany.com/404-error
SHLINK_INVALID_SHORT_URL_REDIRECT=https://mycompany.com/invalid-link
```

---

## 2. Branding the Shlink Web Client

The Shlink Web Client (`shlinkio/shlink-web-client`) is a React single-page application. Because it runs purely in the client's browser, you can host it on its own subdomain (e.g., `manager.example.com`) and apply your branding.

### 2.1 Logo, Favicon, and Color Customization
To replace the default logo, favicon, and theme color without recompiling the React source code, mount your custom brand assets directly into the web client container:

```yaml
# Example docker-compose config addition for a branded Web Client:
  shlink-web-client:
    image: shlinkio/shlink-web-client
    container_name: shlink-web-client
    restart: always
    ports:
      - "8000:80"
    volumes:
      # Mount a pre-configured servers.json so users don't have to enter API keys manually
      - ./web-client/servers.json:/usr/share/nginx/html/servers.json:ro
      # Replace logo assets
      - ./web-client/logo.svg:/usr/share/nginx/html/logo.svg:ro
      # Replace favicon
      - ./web-client/favicon.ico:/usr/share/nginx/html/favicon.ico:ro
```

### 2.2 Custom Theme Styling
The Shlink Web Client supports a dark mode and a light mode. You can set the default theme using local storage settings or by recompiling the web-client from source.

---

## 3. Advanced Customization (Requires Custom Development)

### 3.1 Splash Pages & Delayed Redirects
*Native Support: **No***
By default, Shlink performs high-performance, server-level `302 Found` or `301 Moved Permanently` redirects. It cannot display a splash page (e.g. "Redirecting you in 5 seconds...") before sending the user to the destination.

*Workaround (Custom Development):*
1. Point your Shlink short URL to a custom web app page on your server, appending the actual destination as a parameter:
   `https://arogy.am/slug` -> redirects to `https://splash.example.com/index.html?dest=https://finaldestination.com`
2. Your splash page displays your brand logo, advertisements, or tracking scripts, and then executes a JavaScript redirect:
   ```javascript
   const params = new URLSearchParams(window.location.search);
   const destination = params.get('dest');
   setTimeout(() => {
       window.location.href = destination;
   }, 5000);
   ```

### 3.2 Modifying Backend UI Branding
*Native Support: **No***
The Shlink engine itself has no backend UI (it is a headless API). The only backend interface is the React Web Client. If you want to modify structural elements of the web client (like sidebars, menu items, or labels), you must fork the official [shlink-web-client repository](https://github.com/shlinkio/shlink-web-client), make your edits in React, and build a custom Docker image.
