# MCP Credentials

This workspace loads MCP secrets from `~/.config/ecommerce/secrets.env`, outside the
bind-mounted workspace. Never put real credentials in `.envrc`, `.opencode/`, Git, or
the devcontainer configuration.

Create the file once and restrict it to the current user:

```sh
mkdir -p ~/.config/ecommerce
touch ~/.config/ecommerce/secrets.env
chmod 600 ~/.config/ecommerce/secrets.env
```

The root `.envrc` sources this file. After changing it, run `direnv allow` from the
workspace root or start a new shell, then restart OpenCode. MCP configuration is loaded
only when OpenCode starts.

## Secret Inventory

| MCP | Credential | Host or devcontainer | Access |
| --- | --- | --- | --- |
| `context7` | `CONTEXT7_API_KEY` | host and devcontainer | Documentation API key |
| `github` | `GITHUB_PERSONAL_ACCESS_TOKEN` | host | Depends on PAT permissions |
| `github` | `GITHUB_TOKEN_DEVCONTAINER` | devcontainer | Read-only fine-grained PAT |
| `grafana-cloud` | `GRAFANA_CLOUD_URL`, `GRAFANA_CLOUD_TOKEN` | host | Read-only Grafana MCP |
| `mongodb-local` | `MDB_MCP_LOCAL_CONNECTION_STRING` | host | Database user with `read` only |
| `mongodb-prod` | `MDB_MCP_PROD_CONNECTION_STRING` | host | Database user with `read` only |
| `kubernetes-local` | `KUBECONFIG_MCP_LOCAL` | host | Local k3d admin kubeconfig |
| `kubernetes-prod` | `KUBECONFIG_MCP_PROD` | host | ServiceAccount bound to `view` |
| `redpanda-local` | None | host | Local unauthenticated broker on `localhost:9092` |
| `redpanda-prod` | None | host | Local port-forward on `localhost:19092` |
| `playwright` | None | host or devcontainer | Browser automation |
| `grafana-local` | None | host | Local Grafana default development credentials |

## Grafana Cloud

`grafana-cloud` runs `mcp-grafana --disable-write`. It needs a Grafana **service account
token**, not a legacy API key and not a Grafana Cloud access-policy token. The token must
belong to the Grafana stack configured as `GRAFANA_CLOUD_URL`.

1. Open the Grafana Cloud stack URL, such as `https://<stack>.grafana.net`.
2. Go to **Administration** > **Users and access** > **Service accounts**.
3. Create a service account named `opencode-mcp-readonly`.
4. Assign the **Viewer** role. Do not use Editor or Admin.
5. Create a token for that service account. Set an expiration if the UI supports it and
   record the rotation date.
6. Copy the token immediately. Grafana displays it only once.
7. Add it to `~/.config/ecommerce/secrets.env`:

```sh
export GRAFANA_CLOUD_URL="https://<stack>.grafana.net"
export GRAFANA_CLOUD_TOKEN="<service-account-token>"
```

The Viewer role provides baseline read access to dashboards and data sources. If a Grafana
MCP read tool returns `403`, add only the required custom RBAC permissions, such as
`dashboards:read`, `datasources:read`, `alert.rules:read`, or folder-specific read scopes.
Keep `--disable-write` in the MCP configuration even when RBAC is broadened.

Grafana Cloud also has **Access Policies** for hosted metrics, logs, traces, profiles, and
alerts. Use them for Alloy ingestion or direct Mimir/Loki/Tempo clients. They are not the
credential expected by the current `mcp-grafana` configuration.

## GitHub

Create two separate **fine-grained personal access tokens**.

### Host token

1. Open GitHub **Settings** > **Developer settings** > **Personal access tokens** >
   **Fine-grained tokens** > **Generate new token**.
2. Set the resource owner and choose **Only select repositories**. Select only the
   `ecommerce-*` repositories that this workspace needs.
3. Set the shortest practical expiration.
4. Give only the permissions you use. A read-only baseline is:
   `Contents: Read`, `Pull requests: Read`, `Issues: Read`, `Actions: Read`, and
   `Commit statuses: Read`. `Metadata: Read` is mandatory.
5. Do not grant `Contents: Write`, Administration, Secrets, Environments, Webhooks, or
   Workflows write permissions unless a specific workflow requires them.
6. Save it as:

```sh
export GITHUB_PERSONAL_ACCESS_TOKEN="<host-fine-grained-pat>"
```

### Devcontainer token

Repeat the same flow, with a separate token named `opencode-devcontainer-readonly`. Keep it
strictly read-only and scoped only to workspace repositories:

```sh
export GITHUB_TOKEN_DEVCONTAINER="<read-only-fine-grained-pat>"
```

`devcontainer.json` maps this value to `GITHUB_PERSONAL_ACCESS_TOKEN` inside the container.
Never pass the host token into the devcontainer.

## Context7

1. Create or sign in to the Context7 account used by the team.
2. Create an API key in its dashboard.
3. Store it as:

```sh
export CONTEXT7_API_KEY="<context7-api-key>"
```

If Context7 is unavailable, its MCP fails independently; it does not affect the local MCP
servers.

## MongoDB

Create separate database users for local and production. The `mongodb-mcp-server` command
already uses `--readOnly`, but MongoDB permissions are the enforcement boundary.

### Local

Create a local MongoDB user with only the built-in `read` role on the databases that MCP may
inspect. Then set a URI that authenticates as that user:

```sh
export MDB_MCP_LOCAL_CONNECTION_STRING="mongodb://opencode_mcp_local:<password>@localhost:27017/?authSource=admin"
```

### Production Atlas

1. In Atlas, open the production project and go to **Database Access**.
2. Add a database user named, for example, `opencode_mcp_prod`.
3. Grant **Read only** access only to the required databases. Do not use `Atlas admin`,
   `readWrite`, or a project owner role.
4. Restrict network access to the host running OpenCode. Do not add `0.0.0.0/0`.
5. Copy the SRV connection string, replace its credentials with the dedicated user, and set:

```sh
export MDB_MCP_PROD_CONNECTION_STRING="mongodb+srv://opencode_mcp_prod:<password>@<cluster>/<database>?retryWrites=true&w=majority"
```

URL-encode reserved characters in MongoDB usernames and passwords.

## Kubernetes

Production uses a dedicated ServiceAccount and kubeconfig. Do not point production MCP at an
admin kubeconfig; it also runs with `--read-only`.

The built-in `view` ClusterRole is an appropriate baseline: it permits reading normal resources
but deliberately excludes Secrets.

### Local k3d

Local Kubernetes MCP intentionally has write access, so it can apply or repair local development
resources. `make init` and `make up` generate an isolated admin kubeconfig automatically:

```sh
cd ecommerce-infrastructure/environments/local
make init # or: make up
```

Set the resulting path once:

```sh
export KUBECONFIG_MCP_LOCAL="$HOME/.kube/mcp-local.kubeconfig"
```

`make clean` removes this generated kubeconfig. This does not grant access to production.

### Production viewer identity

Generate the production viewer identity and kubeconfig with the production Makefile:

```sh
cd ecommerce-infrastructure/environments/production
make tunnel
make mcp-kubeconfig
```

Start the tunnel manually before the target. The target fetches the normal production kubeconfig
if it is missing, then creates or updates the `mcp/opencode-viewer` ServiceAccount with the
built-in `view` role. It generates a token requested for up to 30 days and writes only the cluster
CA, tunnel endpoint, and viewer token to `$HOME/.kube/mcp-prod-viewer.kubeconfig` with permissions
`600`. It never copies the administrator credentials from `$HOME/.kube/config-hetzner`.

Set the resulting paths:

```sh
export KUBECONFIG_MCP_LOCAL="$HOME/.kube/mcp-local.kubeconfig"
export KUBECONFIG_MCP_PROD="$HOME/.kube/mcp-prod-viewer.kubeconfig"
```

Before using production MCP, ensure the API tunnel is healthy. `make tunnel` checks Kubernetes
`/healthz` through the local forward with the production kubeconfig and automatically replaces an
unhealthy tunnel. Its SSH keepalives detect broken VPN or network connections within roughly 90
seconds:

```sh
cd ecommerce-infrastructure/environments/production
make tunnel
```

The request is for a token valid for up to 30 days; the API server can enforce a shorter duration.
Run `make mcp-kubeconfig` again before it expires. If the cluster supports a more durable workload
identity, prefer it over a long-lived bearer token.

## Redpanda

The current local and production Redpanda deployments have SASL disabled. No token is needed.
The MCP config exposes only read tools, so it cannot produce, create, delete, or alter topics.

For production, start the existing SSH tunnel and then forward the in-cluster Kafka listener:

```sh
cd ecommerce-infrastructure/environments/production
make tunnel
make redpanda-kafka
```

If SASL is enabled later, create a dedicated Redpanda principal with ACLs limited to `Describe`
and `Read` for the required topics and consumer groups. Put its credentials in a file outside the
workspace and extend only `.opencode/redpanda-prod.yaml` to reference environment variables.

## Local Grafana and Playwright

`grafana-local` uses the repository's local development Grafana credentials
(`admin` / `admin`) and is not a production credential. `playwright` needs no credential.

## Complete Example

`~/.config/ecommerce/secrets.env` should contain only exports and never be committed:

```sh
export CONTEXT7_API_KEY="..."
export GITHUB_PERSONAL_ACCESS_TOKEN="..."
export GITHUB_TOKEN_DEVCONTAINER="..."
export GRAFANA_CLOUD_URL="https://<stack>.grafana.net"
export GRAFANA_CLOUD_TOKEN="..."
export MDB_MCP_LOCAL_CONNECTION_STRING="..."
export MDB_MCP_PROD_CONNECTION_STRING="..."
export KUBECONFIG_MCP_LOCAL="$HOME/.kube/mcp-local-viewer.kubeconfig"
export KUBECONFIG_MCP_PROD="$HOME/.kube/mcp-prod-viewer.kubeconfig"
```

After adding or rotating any credential:

```sh
chmod 600 ~/.config/ecommerce/secrets.env
direnv allow
```

Restart OpenCode after changing the file. For production Kubernetes and Redpanda, also keep the
required tunnels running for the MCP session.
