package io.opensourcesantiago.aisdlc.events.api;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

/**
 * Integration tests for SSE Event Stream
 * Note: SSE endpoints return continuous streams, so we just verify they respond
 */
@QuarkusTest
public class EventStreamResourceTest {

    @Test
    public void testStreamEventsEndpointExists() {
        // SSE endpoint should respond with text/event-stream
        given()
            .when()
            .get("/api/stream/events")
            .then()
            .statusCode(200)
            .contentType("text/event-stream;charset=UTF-8");
    }

    @Test
    public void testStreamActiveEndpointExists() {
        given()
            .when()
            .get("/api/stream/active")
            .then()
            .statusCode(200)
            .contentType("text/event-stream;charset=UTF-8");
    }

    @Test
    public void testStreamStatisticsEndpointExists() {
        given()
            .when()
            .get("/api/stream/statistics")
            .then()
            .statusCode(200)
            .contentType("text/event-stream;charset=UTF-8");
    }

    @Test
    public void testStreamDashboardEndpointExists() {
        given()
            .when()
            .get("/api/stream/dashboard")
            .then()
            .statusCode(200)
            .contentType("text/event-stream;charset=UTF-8");
    }

    @Test
    public void testDashboardPageAccessible() {
        given()
            .when()
            .get("/dashboard/")
            .then()
            .statusCode(200)
            .contentType(ContentType.HTML);
    }

    @Test
    public void testRootRedirectsToDashboard() {
        given()
            .redirects().follow(false)
            .when()
            .get("/")
            .then()
            .statusCode(200)  // Serves redirect page
            .contentType(ContentType.HTML);
    }
}
