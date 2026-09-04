To generate code install [openapi2zig](https://github.com/christianhelle/openapi2zig)

Linux/macOS:

```bash
curl -fsSL https://christianhelle.com/openapi2zig/install | bash
```

Windows (PowerShell Core):

```powershell
irm https://christianhelle.com/openapi2zig/install.ps1 | iex
```

then run the following:

```bash
openapi2zig generate -i openapi.json -o . --multiple-files --tag issues --tag pulls --tag repos
```
