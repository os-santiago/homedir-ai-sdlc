package io.opensourcesantiago.aisdlc.events.health;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for custom health checks
 */
@QuarkusTest
public class HealthChecksTest {

    @Test
    public void testReadinessCheck() {
        given()
            .when().get("/q/health/ready")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("status", is("UP"))
            .body("checks", not(empty()))
            .body("checks.find { it.name == 'Database connectivity' }.status", is("UP"))
            .body("checks.find { it.name == 'Projection sync' }.status", is("UP"));
    }

    @Test
    public void testLivenessCheck() {
        given()
            .when().get("/q/health/live")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("status", is("UP"));
    }

    @Test
    public void testDatabaseHealthCheck() {
        given()
            .when().get("/q/health/ready")
            .then()
            .statusCode(200)
            .body("checks.find { it.name == 'Database connectivity' }.data.event_count",
                  greaterThanOrEqualTo(0));
    }

    @Test
    public void testProjectionHealthCheck() {
        given()
            .when().get("/q/health/ready")
            .then()
            .statusCode(200)
            .body("checks.find { it.name == 'Projection sync' }.data.lag",
                  lessThanOrEqualTo(100));
    }
}
