Get latest tags of ministack images:

```bash
curl -s "https://hub.docker.com/v2/repositories/ministackorg/ministack/tags?page_size=10" | jq -r '.results[] | "\(.name) \(.last_updated)"'
```

```powershell
Invoke-RestMethod "https://hub.docker.com/v2/repositories/ministackorg/ministack/tags?page_size=10" | Select-Object -ExpandProperty results | Select-Object name, last_updated
```


