# Repository Cleanup Analysis - November 12, 2025

## Executive Summary

**Total Files Analyzed**: 170+ files  
**Empty Files Found**: 16 files (9 .md, 7 .ps1)  
**Redundant Documentation**: ~40 files  
**Recommended for Deletion**: 56 files  
**Recommended for Archival**: 15 files  
**Files to Keep**: Core incident docs, execution scripts, timelines  

---

## Category 1: EMPTY FILES - DELETE IMMEDIATELY ✅

### Empty Markdown Files (9 files)
```
INCIDENT-5C-DATADOG-VERIFICATION.md (0 bytes)
INCIDENT-5C-ORDER-PROCESSING-BLOCKED.md (0 bytes)
INCIDENT-8-ANALYSIS.md (0 bytes)
INCIDENT-8-QUICK-START.md (0 bytes)
INCIDENT-8-REAL-SOLUTION.md (0 bytes)
INCIDENT-8-vs-8A-COMPARISON.md (0 bytes)
INCIDENT-8A-DATABASE-SLOWNESS-CORRECT.md (0 bytes)
INCIDENT-8B-DATABASE-LOAD-TESTING.md (0 bytes)
SYSTEM-HEALTH-REPORT.md (0 bytes)
```

### Empty PowerShell Scripts (7 files)
```
incident-8-activate-slowness.ps1 (0 bytes)
incident-8-activate.ps1 (0 bytes)
incident-8-recover.ps1 (0 bytes)
incident-8a-activate.ps1 (0 bytes)
incident-8a-recover.ps1 (0 bytes)
incident-8b-activate.ps1 (0 bytes)
incident-8b-recover.ps1 (0 bytes)
```

**Action**: DELETE - No content, no value

---

## Category 2: INCIDENT-5C - MASSIVE REDUNDANCY

### Problem
INCIDENT-5C has 25 documentation files with significant overlap.

### Files to KEEP (Core + Timeline)

**Primary Documentation** (3 files):
1. `INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md` - Core requirement analysis
2. `INCIDENT-5C-TEST-EXECUTION-REPORT.md` - Nov 11 successful test (TIMELINE)
3. `INCIDENT-5C-EXECUTION-ANALYSIS-2025-11-12-FINAL.md` - Nov 12 analysis (TIMELINE)

**Execution Script** (1 file):
4. `incident-5c-execute-fixed.ps1` - Working script with fix

### Files to DELETE (Redundant - 21 files)

**Redundant Guides**:
```
INCIDENT-5C-COMPLETE-GUIDE.md - Superseded by DEFINITIVE
INCIDENT-5C-DOCUMENTATION-INDEX.md - Index of redundant docs
INCIDENT-5C-FINAL-OVERVIEW.md - Duplicate of DEFINITIVE
INCIDENT-5C-FINAL-VERDICT.md - Merged into DEFINITIVE
INCIDENT-5C-IMPLEMENTATION-PLAN.md - Completed, archived in TEST-EXECUTION
INCIDENT-5C-PRE-EXECUTION-HEALTH-CHECK.md - Standard procedure
INCIDENT-5C-QUICK-REFERENCE.md - Too brief, info in DEFINITIVE
INCIDENT-5C-READY-FOR-RETEST-2025-11-12.md - Obsolete after retest
INCIDENT-5C-READY-TO-EXECUTE.md - Obsolete after execution
INCIDENT-5C-SUMMARY.md - Superseded by FINAL analysis
```

**Redundant Datadog Docs**:
```
INCIDENT-5C-DATADOG-QUERIES.md - Consolidated into TEST-EXECUTION
INCIDENT-5C-DATADOG-WORKING-QUERIES.md - Duplicate
```

**Redundant Nov 12 Docs**:
```
INCIDENT-5C-EXECUTION-REPORT-2025-11-12.md - Superseded by FINAL
INCIDENT-5C-FAILURE-ANALYSIS-2025-11-12.md - Merged into FINAL
INCIDENT-5C-FIX-SUMMARY-2025-11-12.md - Merged into FINAL
```

**Redundant Frontend/Implementation**:
```
INCIDENT-5C-FRONTEND-FIX-COMPLETE.md - Implementation complete
```

**Redundant Scripts**:
```
incident-5c-execute.ps1 - Old version without fix
incident-5c-execute-fixed-v2.ps1 - Experimental version
```

---

## Category 3: INCIDENT-5 (Original) - CONSOLIDATE

### Files to KEEP (2 files)
1. `INCIDENT-5-ASYNC-PROCESSING-FAILURE.md` - Core incident definition
2. `incident-5-activate.ps1` - Execution script

### Files to DELETE (Redundant - 10 files)
```
INCIDENT-5-ANALYSIS.md - Superseded by 5C analysis
INCIDENT-5-CORRECTED-QUERIES.md - Queries in 5C docs
INCIDENT-5-DATADOG-QUICK-GUIDE.md - Superseded by 5C
INCIDENT-5-DATADOG-VERIFICATION.md - Superseded by 5C
INCIDENT-5-DATADOG-VERIFIED-GUIDE.md - Superseded by 5C
INCIDENT-5-EXPLANATION.md - Covered in ASYNC-PROCESSING
INCIDENT-5-FIXES-SUMMARY.md - Fixes in 5C
INCIDENT-5-TEST-EXECUTION-REPORT.md - Superseded by 5C test
INCIDENT-5A-QUEUE-BLOCKAGE.md - Merged into 5C concept
```

---

## Category 4: INCIDENT-6 - CONSOLIDATE

### Files to KEEP (3 files)
1. `INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md` - Core incident definition
2. `INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md` - Comprehensive guide
3. `INCIDENT-6-TEST-NOV11-SUMMARY.md` - Test timeline (IMPORTANT)

**Scripts to KEEP** (3 files):
4. `incident-6-activate-timed.ps1` - Timed version (NEW, today)
5. `incident-6-activate.ps1` - Standard version
6. `incident-6-recover.ps1` - Recovery script

### Files to DELETE (Redundant - 6 files)
```
INCIDENT-6-CORRECTED-QUERIES.md - Queries in OBSERVABILITY-GUIDE
INCIDENT-6-DOCUMENTATION-COMPLETE.md - Meta doc
INCIDENT-6-NOV10-LOGS-MISSING-ANALYSIS.md - Historical issue, resolved
INCIDENT-6-QUERY-UPDATE-SUMMARY.md - Merged into OBSERVABILITY
INCIDENT-6-READY-TO-TEST.md - Obsolete after testing
INCIDENT-6-TIMELINE-UPDATED.md - Timeline in TEST-NOV11
incident-6-timer.ps1 - Superseded by activate-timed.ps1
```

---

## Category 5: INCIDENT-7 - CONSOLIDATE

### Files to KEEP (3 files)
1. `INCIDENT-7-AUTOSCALING-FAILURE.md` - Core incident definition
2. `INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md` - Comprehensive guide
3. `INCIDENT-7-TEST-EXECUTION-REPORT.md` - Test timeline

**YAML to KEEP** (2 files):
4. `incident-7-broken-hpa.yaml` - Incident config
5. `incident-7-correct-hpa.yaml` - Recovery config

### Files to DELETE (Redundant - 2 files)
```
INCIDENT-7-DATADOG-QUERIES-CORRECTED.md - Queries in OBSERVABILITY
INCIDENT-7-DATADOG-QUERIES-LATEST.md - Queries in OBSERVABILITY
```

---

## Category 6: INCIDENT-8/8A/8B - INCOMPLETE

### Files to KEEP (2 files)
1. `INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md` - Core definition
2. `INCIDENT-8B-DATADOG-VERIFICATION-GUIDE.md` - Datadog guide
3. `INCIDENT-8B-QUERY-GUIDE.md` - Query reference

### Files to DELETE (Empty - 8 files)
Already listed in Category 1 (empty files)

---

## Category 7: DATADOG DOCUMENTATION - CONSOLIDATE

### Files to KEEP (Core - 3 files)
1. `DATADOG-ANALYSIS-GUIDE.md` - General Datadog usage
2. `RABBITMQ-DATADOG-PERMANENT-FIX.md` - RabbitMQ metrics fix (IMPORTANT)
3. `DATADOG-LOG-COLLECTION-REGRESSION-FIX-2025-11-12.md` - Nov 12 fix (TIMELINE)

### Files to DELETE (Redundant - 10 files)
```
DATADOG-COMPLETE-HEALTH-CHECK-2025-11-12.md - Procedure documented elsewhere
DATADOG-DNS-FIX-APPLIED.md - Historical fix, resolved
DATADOG-SERVICE-NAMING-ISSUE.md - Historical issue, resolved
DATADOG-STATUS-COMPLETE.md - Status snapshot, obsolete
DATADOG-VERIFICATION-INCIDENT-5.md - Incident-specific, in 5C docs
RABBITMQ-COMPLETE-OBSERVABILITY-SOLUTION.md - Duplicate of PERMANENT-FIX
RABBITMQ-DATADOG-VERIFICATION-GUIDE.md - Verification in PERMANENT-FIX
RABBITMQ-FIX-SUMMARY.md - Summary in PERMANENT-FIX
RABBITMQ-METRICS-ENABLED-SUCCESS.md - Success confirmation, obsolete
```

---

## Category 8: GENERAL DOCUMENTATION - REVIEW

### Files to KEEP (Essential - 8 files)
1. `README.md` - Repository overview
2. `SOCK-SHOP-COMPLETE-ARCHITECTURE.md` - Architecture reference
3. `SOCK-SHOP-COMPLETE-DEMO-GUIDE.md` - Demo guide
4. `INCIDENT-SIMULATION-MASTER-GUIDE.md` - Master incident guide
5. `COMPLETE-SETUP-GUIDE.md` - Setup instructions
6. `PORT-MAPPING-REFERENCE.md` - Port reference
7. `SESSION-SUMMARY-2025-11-07.md` - Historical session (TIMELINE)
8. `ULTRA-ANALYSIS-SUMMARY.md` - Analysis summary

### Files to DELETE (Redundant/Obsolete - 11 files)
```
BUG-FIX-IMPLEMENTATION-GUIDE.md - Bugs fixed, historical
CHANGELOG-2025-11-10.md - Historical changelog
COMPREHENSIVE-HEALTH-CHECK-PROCEDURE.md - Procedure in MASTER-GUIDE
CRITICAL-BUG-ORDER-PAYMENT-BYPASS.md - Bug fixed, historical
DOCUMENTATION-UPDATE-SUMMARY.md - Meta doc, obsolete
EXECUTE-NOW.md - Obsolete execution note
OPTIONAL-FRONTEND-ORDERS-FIX.md - Optional fix, not needed
PORT-FORWARD-GUIDE.md - Info in PORT-MAPPING-REFERENCE
POST-FIX-HEALTH-CHECK-REPORT.md - Historical report
PRE-INCIDENT-HEALTH-CHECK-REPORT.md - Historical report
SYSTEM-HEALTH-STATUS-NOV11.md - Status snapshot, obsolete
USER-REGISTRATION-ERROR-FIX.md - Bug fixed, historical
```

---

## Category 9: SCRIPTS & CONFIGS - REVIEW

### Scripts to KEEP (Active - 8 files)
```
incident-5-activate.ps1
incident-5c-execute-fixed.ps1
incident-6-activate-timed.ps1
incident-6-activate.ps1
incident-6-recover.ps1
apply-rabbitmq-fix.ps1
verify-datadog-logs-working.ps1
```

### Scripts to DELETE (Obsolete - 15+ files)
```
analyze-orders-source.ps1 - Analysis complete
apply-rabbitmq-management-plugin.ps1 - Plugin enabled, obsolete
check-datadog-metrics.ps1 - Ad-hoc check
enable-rabbitmq-metrics.ps1 - Metrics enabled
fix-datadog-dns-http.ps1 - DNS fixed
fix-dns-after-restart.ps1 - DNS fixed
place-test-orders.ps1 - Testing script
query-specific-metric.ps1 - Ad-hoc query
set-rabbitmq-policy.ps1 - Policy in incident scripts
switch-to-management-image.ps1 - Image switched
test-payment-now.ps1 - Ad-hoc test
test-rabbitmq-metrics.ps1 - Metrics tested
update-datadog-key.ps1 - One-time update
view-rabbitmq-metrics.ps1 - Metrics viewable in Datadog
```

### YAML to DELETE (Obsolete - 10+ files)
```
coredns-backup.yaml - Backup, DNS fixed
coredns-fixed.yaml - Applied, DNS fixed
enable-management-via-config.yaml - Applied
enable-rabbitmq-management-plugin.yaml - Applied
enable-rabbitmq-metrics.ps1 - Applied
fix-exporter-port-annotation.yaml - Applied
rabbitmq-backup-before-plugin-*.yaml - Backup
rabbitmq-datadog-annotations-patch.yaml - Applied
rabbitmq-deployment-backup-*.yaml - Backup
rabbitmq-disable-native-check.yaml - Empty
rabbitmq-enable-management-plugin.yaml - Applied
rabbitmq-exporter-port-fix.yaml - Applied
remove-posthook-enable-plugin-properly.yaml - Applied
servicemonitor-rabbitmq.yaml - Not used
test-dns-pod.yaml - Testing artifact
```

---

## SUMMARY OF RECOMMENDATIONS

### DELETE IMMEDIATELY (56 files)

**Empty Files** (16):
- 9 empty .md files
- 7 empty .ps1 files

**Redundant INCIDENT-5C Docs** (21):
- Superseded guides, analyses, summaries

**Redundant INCIDENT-5 Docs** (10):
- Superseded by 5C documentation

**Redundant INCIDENT-6 Docs** (6):
- Query docs, meta docs, obsolete timelines

**Redundant INCIDENT-7 Docs** (2):
- Query docs merged into observability guide

**Redundant Datadog Docs** (10):
- Historical fixes, duplicate guides

**Redundant General Docs** (11):
- Bug fixes, changelogs, historical reports

**Obsolete Scripts** (15):
- One-time fixes, ad-hoc tests

**Obsolete YAML** (10):
- Applied patches, backups

**Total**: 56 files for deletion

---

### KEEP (Core Files - 35 files)

**Incident Documentation** (15):
- INCIDENT-1 through INCIDENT-8 core definitions
- INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md
- INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md
- INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md
- Test execution reports (timelines)

**Execution Scripts** (8):
- incident-5-activate.ps1
- incident-5c-execute-fixed.ps1
- incident-6-activate-timed.ps1
- incident-6-activate.ps1
- incident-6-recover.ps1
- incident-7 YAML configs
- apply-rabbitmq-fix.ps1
- verify-datadog-logs-working.ps1

**General Documentation** (8):
- README.md
- SOCK-SHOP-COMPLETE-ARCHITECTURE.md
- SOCK-SHOP-COMPLETE-DEMO-GUIDE.md
- INCIDENT-SIMULATION-MASTER-GUIDE.md
- COMPLETE-SETUP-GUIDE.md
- PORT-MAPPING-REFERENCE.md
- RABBITMQ-DATADOG-PERMANENT-FIX.md
- DATADOG-ANALYSIS-GUIDE.md

**Timeline/Historical** (4):
- SESSION-SUMMARY-2025-11-07.md
- INCIDENT-5C-TEST-EXECUTION-REPORT.md (Nov 11)
- INCIDENT-5C-EXECUTION-ANALYSIS-2025-11-12-FINAL.md (Nov 12)
- INCIDENT-6-TEST-NOV11-SUMMARY.md
- DATADOG-LOG-COLLECTION-REGRESSION-FIX-2025-11-12.md

---

## ARCHIVE FOLDER

### Current Archive
```
archive/incident-6-tests/ (3 files)
- INCIDENT-6-LIVE-TEST-2025-11-07.md
- INCIDENT-6-TEST-REPORT-2025-11-07.md
- INCIDENT-6-TEST-RESULTS-FINAL.md
```

**Action**: Keep as-is (historical test data)

---

## IMPLEMENTATION PLAN

### Phase 1: Delete Empty Files (16 files)
**Risk**: ZERO - No content to lose  
**Action**: Delete immediately

### Phase 2: Delete Redundant INCIDENT-5/5C Docs (31 files)
**Risk**: LOW - Content preserved in core docs  
**Action**: Verify core docs contain all valuable data, then delete

### Phase 3: Delete Redundant INCIDENT-6/7 Docs (8 files)
**Risk**: LOW - Content in observability guides  
**Action**: Delete

### Phase 4: Delete Redundant Datadog Docs (10 files)
**Risk**: LOW - Fixes applied, content in PERMANENT-FIX  
**Action**: Delete

### Phase 5: Delete Obsolete Scripts/YAML (25 files)
**Risk**: LOW - One-time fixes, backups  
**Action**: Delete

### Phase 6: Delete Redundant General Docs (11 files)
**Risk**: LOW - Historical/meta docs  
**Action**: Delete

---

## FINAL REPOSITORY STRUCTURE

```
d:\sock-shop-demo/
├── Core Incident Docs (15 files)
│   ├── INCIDENT-1-APP-CRASH.md
│   ├── INCIDENT-2-HYBRID-CRASH-LATENCY.md
│   ├── INCIDENT-3-PAYMENT-FAILURE.md
│   ├── INCIDENT-4-APP-LATENCY.md
│   ├── INCIDENT-5-ASYNC-PROCESSING-FAILURE.md
│   ├── INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md
│   ├── INCIDENT-5C-TEST-EXECUTION-REPORT.md
│   ├── INCIDENT-5C-EXECUTION-ANALYSIS-2025-11-12-FINAL.md
│   ├── INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md
│   ├── INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md
│   ├── INCIDENT-6-TEST-NOV11-SUMMARY.md
│   ├── INCIDENT-7-AUTOSCALING-FAILURE.md
│   ├── INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md
│   ├── INCIDENT-7-TEST-EXECUTION-REPORT.md
│   └── INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md
│
├── Execution Scripts (8 files)
│   ├── incident-5-activate.ps1
│   ├── incident-5c-execute-fixed.ps1
│   ├── incident-6-activate-timed.ps1
│   ├── incident-6-activate.ps1
│   ├── incident-6-recover.ps1
│   ├── incident-7-broken-hpa.yaml
│   ├── incident-7-correct-hpa.yaml
│   └── apply-rabbitmq-fix.ps1
│
├── General Documentation (10 files)
│   ├── README.md
│   ├── SOCK-SHOP-COMPLETE-ARCHITECTURE.md
│   ├── SOCK-SHOP-COMPLETE-DEMO-GUIDE.md
│   ├── INCIDENT-SIMULATION-MASTER-GUIDE.md
│   ├── COMPLETE-SETUP-GUIDE.md
│   ├── PORT-MAPPING-REFERENCE.md
│   ├── RABBITMQ-DATADOG-PERMANENT-FIX.md
│   ├── DATADOG-ANALYSIS-GUIDE.md
│   ├── DATADOG-LOG-COLLECTION-REGRESSION-FIX-2025-11-12.md
│   └── SESSION-SUMMARY-2025-11-07.md
│
├── Supporting Files
│   ├── Makefile
│   ├── LICENSE
│   ├── rabbitmq-datadog-fix-permanent.yaml
│   ├── stripe-mock-deployment.yaml
│   └── verify-datadog-logs-working.ps1
│
└── Directories
    ├── archive/ (historical tests)
    ├── automation/ (deployment automation)
    ├── front-end-source/ (application code)
    ├── load/ (load testing)
    ├── manifests/ (Kubernetes manifests)
    ├── payment-gateway-service/ (service code)
    └── shipping/ (service code)
```

**Total Files After Cleanup**: ~35 core documentation files + scripts + supporting files

---

## VALIDATION CHECKLIST

Before deleting any file, verify:

✅ **Timelines Preserved**: All test execution reports with dates kept  
✅ **Core Definitions**: One definitive doc per incident  
✅ **Working Scripts**: All active execution scripts kept  
✅ **Datadog Queries**: Consolidated in observability guides  
✅ **Architecture**: Complete architecture doc kept  
✅ **Setup**: Complete setup guide kept  
✅ **Historical Context**: Key session summaries kept  

---

**Analysis Complete**: 2025-11-12  
**Files Analyzed**: 170+  
**Recommended Deletions**: 56 files  
**Recommended Retention**: 35 core files  
**Space Savings**: ~500KB documentation  
**Clarity Improvement**: Massive - from 79 .md files to 25 core files
