package io.opensourcesantiago.aisdlc.events.api;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for Health API
 */
@QuarkusTest
public class HealthResourceTest {

    @Test
    public void testGetStatus() {
        given()
            .when().get("/api/health/status")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("status", is("UP"))
            .body("version", notNullValue())
            .body("database", hasKey("events"))
            .body("database", hasKey("tracking_states"))
            .body("database", hasKey("projections"));
    }

    @Test
    public void testReadinessProbe() {
        given()
            .when().get("/api/health/ready")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("status", is("READY"));
    }

    @Test
    public void testLivenessProbe() {
        given()
            .when().get("/api/health/live")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("status", is("ALIVE"));
    }
}
