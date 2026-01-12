# QSights Disaster Recovery Guide

**Last Updated:** 12 January 2026

---

## 🛡️ What's Protected

| Component | Location | Safe From Laptop Loss? |
|-----------|----------|------------------------|
| Frontend Code | GitHub (`yashbant/qsights-vibe`) | ✅ Yes |
| Backend Code | GitHub (`yashbant/qsights-vibe`) | ✅ Yes |
| Database | AWS RDS (cloud) | ✅ Yes - Always on cloud |
| Production App | EC2 Server (`13.126.210.220`) | ✅ Yes |
| Uploaded Media | EC2 Server | ✅ Yes |
| Environment Files | OneDrive (`Backup_laptop/QSights_env_backup`) | ✅ Yes |
| Backup Scripts | OneDrive + GitHub | ✅ Yes |

---

## 📂 OneDrive Backup Location

```
OneDrive > My files > Backup_laptop > QSights_env_backup > backups/
├── scripts/          # Backup & restore scripts
├── env-files/        # .env files (CRITICAL)
├── database/         # SQL backups
├── code-snapshots/   # Code archives
└── 2026-01-10/       # Additional backups
```

---

## 🔄 Full Recovery Steps (If Laptop Lost)

### Step 1: Clone Repository
```bash
git clone git@github.com:yashbant/qsights-vibe.git QSightsOrg2.0
cd QSightsOrg2.0
```

### Step 2: Download from OneDrive
Download these from `OneDrive > Backup_laptop > QSights_env_backup > backups/env-files/`:
- `backend.env` → Copy to `backend/.env`
- `frontend.env.local` → Copy to `frontend/.env.local`

### Step 3: Install Dependencies
```bash
# Frontend
cd frontend
npm install

# Backend
cd ../backend
composer install
```

### Step 4: Start Development
```bash
# Terminal 1 - Frontend
cd frontend && npm run dev

# Terminal 2 - Backend
cd backend && php artisan serve
```

---

## 🗄️ Database Backup (Manual)

The database is on AWS RDS and is always safe. To create a local backup:

### Terminal 1 - Start SSM Port Forward
```bash
aws ssm start-session --region ap-south-1 --target i-0de19fdf0bd6568b5 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="qsights-db.c0vxik9s9ktk.ap-south-1.rds.amazonaws.com",portNumber="5432",localPortNumber="7400"
```

### Terminal 2 - Run Backup
```bash
cd /Users/yash/Documents/Projects/QSightsOrg2.0
./backups/scripts/backup.sh database
```

---

## 🚀 Production Deployment

### SSH to Server
```bash
ssh -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem ubuntu@13.126.210.220
```

### Deploy Frontend
```bash
cd /var/www/QSightsOrg2.0/frontend
git pull origin main
npm install
npm run build
pm2 restart qsights-frontend
```

### Deploy Backend
```bash
cd /var/www/QSightsOrg2.0/backend
git pull origin main
composer install --no-dev
php artisan migrate --force
php artisan config:cache
php artisan route:cache
```

---

## 🔑 Critical Files to Keep Safe

| File | Purpose | Backup Location |
|------|---------|-----------------|
| `QSights-Mumbai-12Aug2019.pem` | SSH access to server | `/Users/yash/Documents/PEMs/` |
| `backend/.env` | Backend secrets | OneDrive |
| `frontend/.env.local` | Frontend config | OneDrive |
| AWS Credentials | AWS access | AWS Console |
| GitHub SSH Key | Git push/pull | `~/.ssh/id_ed25519` |

---

## 📞 Quick Reference

| Service | Access |
|---------|--------|
| GitHub Repo | https://github.com/yashbant/qsights-vibe |
| Production URL | https://prod.qsights.com |
| AWS Console | https://console.aws.amazon.com |
| EC2 Server | `ubuntu@13.126.210.220` |
| RDS Database | `qsights-db.c0vxik9s9ktk.ap-south-1.rds.amazonaws.com` |
| Database Name | `qsights-db` |
| Database User | `qsights_user` |

---

## ✅ Recovery Checklist

- [ ] Clone repo from GitHub
- [ ] Download .env files from OneDrive
- [ ] Copy .env files to correct locations
- [ ] Run `npm install` in frontend
- [ ] Run `composer install` in backend
- [ ] Test local development
- [ ] Verify production is running

---

*This document should be kept updated whenever infrastructure changes are made.*
