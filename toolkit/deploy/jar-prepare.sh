#!/bin/bash
# Step 2: Copy boot jar to app.jar

deploy_step_prepare_jars() {
  deploy_log "  [2/5] Preparing jars..."
  ssh -n "$SERVER" "mkdir -p $REMOTE"
  local s libs_dir jar_dest jar size
  for s in "${SERVICES[@]}"; do
    [ "$SERVICE" != "all" ] && [ "$SERVICE" != "$s" ] && continue
    is_deployable_service "$s" || continue
    libs_dir="$(module_jar_libs_dir "$s")"
    jar_dest="$(module_jar_dest "$s")"
    jar=$(find "$libs_dir/" -name "*-boot.jar" 2>/dev/null | head -1)
    [ -z "$jar" ] && jar=$(find "$libs_dir/" -name "*.jar" 2>/dev/null | grep -iv plain | head -1)
    if [ -z "$jar" ]; then
      deploy_log "  [WARN] No jar for $s — skipping"
      continue
    fi
    cp "$jar" "$jar_dest"
    size=$(du -h "$jar" | cut -f1)
    deploy_log "  [OK]   app.jar  ($s, $size)"
  done
}
