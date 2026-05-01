# Hermes Setup

Add the following to ~/.hermes/config.yaml

```
mcp_servers:
  firecrawl:
    args:
    - -y
    - firecrawl-mcp
    command: npx
    enabled: true
    env:
      FIRECRAWL_API_URL: http://localhost:3002
```
