# static-deploy

Woodpecker plugin that deploys a built static site to a server over SSH as a
new release, then switches the site's `current` symlink to it.

```
rsync _site/ → <site>/releases/<timestamp>-<sha>/   (unchanged files hardlinked from current)
ssh "activate <site> <release>"                    (atomic symlink swap + prune)
```

## Usage

```yaml
  - name: deploy
    image: ghcr.io/d34ndev/static-deploy:1
    settings:
      site: deanpcmad.com
      source: _site
      host: 100.x.y.z
      ssh_key:
        from_secret: deploy_ssh_key
      known_hosts:
        from_secret: deploy_known_hosts
```

| Setting       | Required | Default  | Notes                                                   |
|---------------|----------|----------|---------------------------------------------------------|
| `site`        | yes      |          | site directory on the server, e.g. `deanpcmad.com`      |
| `source`      | no       | `_site`  | build output directory                                  |
| `host`        | yes      |          | server address. Use the Tailscale IP: MagicDNS may not resolve in step containers |
| `user`        | no       | `deploy` |                                                         |
| `ssh_key`     | yes      |          | private key, from a secret                              |
| `known_hosts` | yes      |          | the server's host key line (`<host> ssh-ed25519 AAAA…`), so host key checking stays on |

Limit both secrets to the `ghcr.io/d34ndev/static-deploy` image so that build
steps can't read them.

## What the server needs

The key's `authorized_keys` entry should force a gate script:

```
command="/usr/local/bin/deploy-gate",restrict ssh-ed25519 AAAA... woodpecker-deploy
```

The gate has to handle two commands:

- `rsync …`: passed to `rrsync -wo /srv/sites`. Paths are relative to that
  root, which is why `--link-dest` is `/<site>/current/`.
- `activate <site> <release>`: points `<site>/current` at
  `releases/<release>`, and prunes old releases.

`<site>/releases/` must already exist on the server.

The upload compares files by checksum, not mtime, because a fresh CI build
touches every file, and mtime comparison would never hardlink anything. Files
arrive as 644 and directories as 755, whatever the build produced.

## Releasing

Pushes to `main` publish `latest` and `sha-<commit>`. Pull requests build
without publishing. Version tags publish semver image tags:

```bash
git tag v1.0.0 && git push origin v1.0.0   # → :1, :1.0, :1.0.0
```

Pipelines pin `:1`, so a `v1.x.y` tag reaches every site on its next deploy.
Make breaking changes as `v2`.

The package is private by default. Once it has been published, make it public
under Package settings → Change visibility, so Woodpecker can pull it without
registry credentials.
