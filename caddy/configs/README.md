# Caddy Configs Directory

Any file ending in `.conf` placed in this directory will be automatically imported into Caddy at startup (via the `import configs/*.conf` directive in the main `Caddyfile`).

Use this to define additional sites, custom redirect rules, or domain configurations without modifying the primary `Caddyfile`.
