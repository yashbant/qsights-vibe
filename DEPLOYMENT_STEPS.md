# QSights Production Deployment Guide

## Server Details
- **Instance ID**: `i-0de19fdf0bd6568b5`
- **Hostname**: `ip-172-31-29-248`
- **SSH Key**: `/Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem`

## Production Paths
- **Frontend**: `/var/www/QSightsOrg2.0/frontend`
- **Backend**: `/var/www/QSightsOrg2.0/backend`

## Deployment Method
**NO GIT on production** - Use direct SCP file copy

---

## Step 1: Start AWS SSM Port Forwarding

```bash
aws ssm start-session \
  --target i-0de19fdf0bd6568b5 \
  --document-name AWS-StartPortForwardingSession \
  --parameters "localPortNumber=3320,portNumber=22"
```

Keep this terminal open during deployment.

---

## Step 2: Copy Frontend Files

```bash
# Single file
scp -o StrictHostKeyChecking=no -P 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  "/Users/yash/Documents/Projects/QSightsOrg2.0/frontend/app/PATH/TO/file.tsx" \
  "ubuntu@127.0.0.1:/var/www/QSightsOrg2.0/frontend/app/PATH/TO/file.tsx"

# For paths with brackets like [id], use quotes
scp -o StrictHostKeyChecking=no -P 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  "/Users/yash/Documents/Projects/QSightsOrg2.0/frontend/app/activities/[id]/results/page.tsx" \
  "ubuntu@127.0.0.1:/var/www/QSightsOrg2.0/frontend/app/activities/[id]/results/page.tsx"
```

---

## Step 3: Copy Backend Files

```bash
scp -o StrictHostKeyChecking=no -P 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  "/Users/yash/Documents/Projects/QSightsOrg2.0/backend/app/Http/Controllers/FILE.php" \
  "ubuntu@127.0.0.1:/var/www/QSightsOrg2.0/backend/app/Http/Controllers/FILE.php"
```

---

## Step 4: Rebuild Frontend (REQUIRED after .tsx changes)

```bash
ssh -o StrictHostKeyChecking=no -p 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  ubuntu@127.0.0.1 \
  "cd /var/www/QSightsOrg2.0/frontend && npm run build"
```

---

## Step 5: Restart Services

### Frontend (PM2)
```bash
ssh -o StrictHostKeyChecking=no -p 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  ubuntu@127.0.0.1 \
  "pm2 restart all && pm2 status"
```

### Backend (Laravel - if needed)
```bash
ssh -o StrictHostKeyChecking=no -p 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  ubuntu@127.0.0.1 \
  "cd /var/www/QSightsOrg2.0/backend && php artisan cache:clear && php artisan config:clear"
```

---

## Quick Reference Commands

### SSH into server
```bash
ssh -o StrictHostKeyChecking=no -p 3320 \
  -i /Users/yash/Documents/PEMs/QSights-Mumbai-12Aug2019.pem \
  ubuntu@127.0.0.1
```

### Check PM2 logs
```bash
ssh ... ubuntu@127.0.0.1 "pm2 logs qsights-frontend --lines 50"
```

### Check Laravel logs
```bash
ssh ... ubuntu@127.0.0.1 "tail -50 /var/www/QSightsOrg2.0/backend/storage/logs/laravel.log"
```

---

## Important Notes

1. **Always use port 3320** for SSH/SCP (SSM forwarding port)
2. **Always rebuild frontend** after copying .tsx files
3. **Always restart PM2** after rebuild
4. **Quote paths with brackets** like `[id]` in SCP commands
5. **Backend changes** may need `php artisan` cache clearing
