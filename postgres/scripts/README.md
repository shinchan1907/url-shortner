# PostgreSQL Database Scripts & Maintenance

This directory is intended for custom SQL scripts, database maintenance guidelines, and optimization tasks.

## Maintenance Tasks

Shlink handles its own database schema updates and migrations automatically on container start. However, as a database grows with clicks and analytics, you should occasionally run maintenance commands.

### 1. Manual Vacuuming & Analyzing
PostgreSQL performs autovacuuming by default, but if you experience a high volume of link clicks, you can run a manual `VACUUM ANALYZE` to optimize the query planner:
```bash
docker exec -t shlink-db vacuumdb -U shlink_db_user -d shlink_db -v -z
```

### 2. Checking Database Size
To monitor database size and individual table sizes (especially `api_key_roles` and `visits` tables which grow the fastest):
```bash
docker exec -it shlink-db psql -U shlink_db_user -d shlink_db -c "
SELECT 
    relation AS name,
    pg_size_pretty(pg_total_relation_size(infoc.oid)) AS total_size
FROM pg_catalog.pg_class infoc
JOIN pg_catalog.pg_namespace infon ON infon.oid = infoc.relnamespace
JOIN (SELECT pg_catalog.pg_namespace.nspname AS relation, oid FROM pg_catalog.pg_class JOIN pg_catalog.pg_namespace ON pg_namespace.oid = pg_class.relnamespace) AS rel ON rel.oid = infoc.oid
WHERE infon.nspname = 'public'
ORDER BY pg_total_relation_size(infoc.oid) DESC;"
```

### 3. Cleaning Old Link Visits (Analytics)
If your SSD space is running low or the database size gets too large (hundreds of millions of clicks), you can prune old visit logs using the Shlink CLI:
```bash
# Delete visits older than 365 days
docker exec -it shlink-engine shlink visit:locate -n
docker exec -it shlink-engine shlink visit:threshold-purge --days 365
```
