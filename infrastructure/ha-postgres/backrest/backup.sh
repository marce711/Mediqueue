#!/bin/bash
# Script to run backups using pgBackRest
# This should be executed on the current database leader

# 1. Initialize stanza (only first time)
pgbackrest --stanza=mediqueue stanza-create --log-level-console=info

# 2. Check configuration
pgbackrest --stanza=mediqueue check --log-level-console=info

# 3. Perform a FULL backup (recommended first time)
pgbackrest --stanza=mediqueue --type=full backup --log-level-console=info

# 4. Perform an INCREMENTAL backup
# pgbackrest --stanza=mediqueue --type=incr backup --log-level-console=info
