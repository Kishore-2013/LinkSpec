# LinkSpec: Vercel Deployment Guide (Flutter Web)

This guide documents the mandatory Environment Variables and Dashboard Settings required to deploy the LinkSpec Web application to Vercel.

## 🚀 Vercel Dashboard Settings

> **Note:** These settings are now defined in `vercel.json` and will override any Dashboard values.

| Field                | Value                                          |
| :------------------- | :--------------------------------------------- |
| **Framework Preset** | Other                                          |
| **Build Command**    | `sh build.sh` _(defined in `vercel.json`)_     |
| **Output Directory** | `build/web` _(defined in `vercel.json`)_       |
| **Install Command**  | Skipped _(handled by `build.sh` during build)_ |

---

## 🔑 Environment Variables (.env)

Add the following **Secrets** to your [Vercel Project Settings > Environment Variables](https://vercel.com/dashboard):

### 🌐 Supabase Configuration

| Variable            | Description                               | Example                    |
| :------------------ | :---------------------------------------- | :------------------------- |
| `SUPABASE_URL`      | Your Supabase Project API URL             | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Public access key for client-side queries | `eyJhbGc3...`              |

### 📧 Email Configuration (Used by API routes)

| Variable             | Description                      | Example               |
| :------------------- | :------------------------------- | :-------------------- |
| `GMAIL_EMAIL`        | Sender address for OTP emails    | `example@gmail.com`   |
| `GMAIL_APP_PASSWORD` | 16-character Google App Password | `xxxx xxxx xxxx xxxx` |

### 🛠️ Infrastructure Scaling

| Variable     | Description                             | Example                           |
| :----------- | :-------------------------------------- | :-------------------------------- |
| `SERVER_URL` | Link to the Vercel Node.js API endpoint | `https://linkspec-api.vercel.app` |

---

## 🏗️ Pre-build Checklist

- **Canvaskit Renderer**: The `build.sh` script is hard-coded to use `--web-renderer canvaskit`. This ensures that medical infographics and large images render with GPU acceleration.
- **SPA Routing**: `vercel.json` contains the rewrite rules to ensure that browser refreshes on sub-paths (e.g., `/settings`) don't crash.
- **Node.js API**: Ensure the `API/` folder is correctly deployed as a Serverless Function on the same project or a sub-domain.

---

> [!IMPORTANT]
> Never commit raw `.env` files to git. Use this guide to sync settings across environments manually.
