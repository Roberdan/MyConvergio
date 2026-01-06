# Fixed functions for plan-db.sh
# These replace the buggy originals with proper SQL injection prevention
# and correct wave_id_fk usage
# This file sources all the split function modules

# Source helper functions
source "$(dirname "$0")/plan-db-helpers.sh"

# Source all function modules
source "$(dirname "$0")/plan-db-task.sh"
source "$(dirname "$0")/plan-db-wave.sh"
source "$(dirname "$0")/plan-db-plan.sh"
source "$(dirname "$0")/plan-db-validate.sh"
source "$(dirname "$0")/plan-db-sync.sh"

