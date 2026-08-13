package io.opensourcesantiago.aisdlc.events.api;

import io.opensourcesantiago.aisdlc.events.service.EventPublisher;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for public Events API
 */
@QuarkusTest
public class EventsResourceTest {

    @Inject
    EventPublisher eventPublisher;

    @Test
    @Transactional
    public void testGetRecentEvents() {
        // Given - Publish test events
        eventPublisher.publishIssueDetected(4000, Map.of()).await().indefinitely();

        // When/Then
        given()
            .when().get("/api/events/recent?limit=10")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("size()", greaterThanOrEqualTo(1));
    }

    @Test
    @Transactional
    public void testGetIssueTimeline() {
        // Given
        int issueNumber = 4001;
        eventPublisher.publishIssueDetected(issueNumber, Map.of()).await().indefinitely();
        eventPublisher.publishAdmissionStarted(issueNumber).await().indefinitely();

        // When/Then
        given()
            .when().get("/api/events/timeline/" + issueNumber)
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("size()", is(2))
            .body("[0].eventType", is("issue.detected"))
            .body("[1].eventType", is("admission.started"));
    }

    @Test
    @Transactional
    public void testGetEventsByStage() {
        // Given
        eventPublisher.publishIssueDetected(4002, Map.of()).await().indefinitely();

        // When/Then
        given()
            .when().get("/api/events/stage/DETECTION?limit=10")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("size()", greaterThanOrEqualTo(1))
            .body("[0].stage", is("DETECTION"));
    }

    @Test
    public void testGetActiveIssues() {
        given()
            .when().get("/api/events/active")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON);
    }

    @Test
    public void testGetStageStatistics() {
        given()
            .when().get("/api/events/statistics/stages")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("size()", is(6))  // 6 stages
            .body("[0]", hasKey("stage"))
            .body("[0]", hasKey("total_events"));
    }

    @Test
    public void testGetAdmissionDecisions() {
        given()
            .when().get("/api/events/statistics/admission-decisions")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON);
    }

    @Test
    public void testGetErrorRate() {
        given()
            .when().get("/api/events/statistics/error-rate")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON);
    }

    @Test
    public void testGetThroughput() {
        given()
            .when().get("/api/events/statistics/throughput?days=7")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON);
    }

    @Test
    public void testGetCount() {
        given()
            .when().get("/api/events/count")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("count", greaterThanOrEqualTo(0));
    }

    @Test
    public void testLimitCapping() {
        // Verify limit is capped at 500
        given()
            .when().get("/api/events/recent?limit=9999")
            .then()
            .statusCode(200)
            .body("size()", lessThanOrEqualTo(500));
    }
}
