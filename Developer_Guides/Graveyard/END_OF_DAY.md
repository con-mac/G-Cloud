# 🌙 End of Day Routine

## Quick Command

```bash
cd /home/con-mac/dev/projects/gcloud_automate && docker-compose down
```

---

## What This Does

- ✅ **Stops all containers** (backend, frontend, postgres, redis)
- ✅ **Removes containers** (frees up memory)
- ✅ **Keeps your data** (database persists in volumes)
- ✅ **Keeps Docker images** (no rebuild tomorrow)
- ✅ **Keeps generated documents** (in backend/generated_documents/)

---

## Alternative Options

### Option 1: Just Stop (Faster restart tomorrow)
```bash
docker-compose stop
```
- Containers stay but are stopped
- Fastest restart tomorrow (`docker-compose start`)
- Uses slightly more disk space

### Option 2: Full Cleanup (Clean slate)
```bash
docker-compose down -v
```
- ⚠️ **WARNING**: This removes ALL data including database
- Use only if you want to start fresh
- Will need to re-run migrations and seed data

### Option 3: Keep Running (If you have resources)
```bash
# Do nothing - leave containers running
```
- Fastest to resume work
- Uses system resources (RAM, CPU)
- Good if you'll be back soon

---

## 🌅 Starting Next Day

### After `docker-compose down`:
```bash
cd /home/con-mac/dev/projects/gcloud_automate
docker-compose up -d
```

Wait ~10 seconds, then access:
- Frontend: http://localhost:3000
- Backend: http://localhost:8000

### After `docker-compose stop`:
```bash
docker-compose start
```
Faster restart (containers already exist)

---

## 💾 What Gets Saved

### ✅ Persists Between Restarts:
- Database data (PostgreSQL volume)
- Redis cache data
- Generated Word documents
- Docker images (no rebuild needed)
- Your code changes
- Git commits

### ❌ Gets Cleared:
- Container logs
- Running processes
- In-memory cache
- Temporary files in containers

---

## 🔍 Checking Status Before Shutdown

```bash
# See what's running
docker-compose ps

# Check logs for any errors
docker-compose logs --tail=20

# See disk space used
docker system df
```

---

## 🧹 Weekly Cleanup (Optional)

Once a week, clean up unused Docker resources:

```bash
# Remove unused images and containers
docker system prune -a

# Remove unused volumes (⚠️ careful - this removes data)
docker volume prune
```

---

## 📝 Full End-of-Day Checklist

- [ ] Commit any uncommitted changes
  ```bash
  git add -A
  git commit -m "work in progress"
  git push origin main
  ```

- [ ] Stop containers
  ```bash
  docker-compose down
  ```

- [ ] Optional: Check disk space
  ```bash
  docker system df
  ```

- [ ] Optional: Backup generated documents
  ```bash
  cp -r backend/generated_documents/ backups/documents_$(date +%Y%m%d)/
  ```

---

## 🚀 Quick Reference Card

| Command | Effect | Startup Speed | Data Kept |
|---------|--------|---------------|-----------|
| `docker-compose down` | Stop & remove containers | Medium | ✅ Yes |
| `docker-compose stop` | Just stop containers | Fast | ✅ Yes |
| `docker-compose down -v` | Remove everything | Slow (rebuild) | ❌ No |
| Keep running | Do nothing | Instant | ✅ Yes |

---

## 💡 Recommended Daily Workflow

### End of Day:
```bash
git add -A
git commit -m "daily progress: [what you did]"
git push origin main
docker-compose down
```

### Start of Day:
```bash
cd /home/con-mac/dev/projects/gcloud_automate
git pull origin main  # If working from multiple machines
docker-compose up -d
# Wait 10 seconds
# Access http://localhost:3000
```

---

## ⚠️ Important Notes

1. **Don't use `-v` flag** unless you want to lose all data
2. **Always commit before shutdown** - containers don't save code changes
3. **Generated documents** are saved in `backend/generated_documents/` (persists)
4. **Database data** persists in Docker volumes (survives `down`, not `down -v`)
5. **Redis cache** rebuilds automatically (doesn't affect functionality)

---

**Recommended for tonight:** `docker-compose down` ✅

