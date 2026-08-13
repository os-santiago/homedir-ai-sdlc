package io.opensourcesantiago.aisdlc.events.domain;

/**
 * Pipeline stage enumeration
 */
public enum EventStage {
    DETECTION,
    ADMISSION,
    IMPLEMENTATION,
    PR_MANAGEMENT,
    CI_CHECKS,
    REMEDIATION,
    DEPLOYMENT,
    ERROR
}
