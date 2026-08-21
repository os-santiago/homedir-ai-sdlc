package io.opensourcesantiago.aisdlc.observability;

import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.Response;
import java.io.IOException;
import java.util.Map;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@Path("/api/sdlc")
public class SdlcApiResource {
  @Inject SdlcObservabilityService service;
  @Inject SdlcDashboardSnapshot snapshot;

  @ConfigProperty(name = "sdlc.dashboard.controls-enabled", defaultValue = "false")
  boolean controlsEnabled;

  @GET
  @Path("snapshot")
  public Response snapshot() {
    if (!authorized(false)) return forbidden();
    if (!checkRateLimit()) return tooManyRequests();
    return Response.ok(snapshot.get()).build();
  }

  @GET
  @Path("status")
  public Response status() {
    // Use direct file-based service instead of snapshot for compatibility with bash worker
    return read(service.status());
  }

  @GET
  @Path("heartbeat")
  public Response heartbeat() {
    // Use direct file-based service instead of snapshot for compatibility with bash worker
    return read(service.heartbeat());
  }

  @GET
  @Path("pipeline")
  public Response pipeline() {
    return read(snapshot.get().get("pipeline"));
  }

  @GET
  @Path("issues")
  public Response issues() {
    return read(snapshot.get().get("issues"));
  }

  @GET
  @Path("prs")
  public Response prs() {
    return read(snapshot.get().get("prs"));
  }

  @GET
  @Path("metrics")
  public Response metrics(@QueryParam("days") Integer days) {
    String range = String.valueOf(days == null ? 30 : Math.max(7, Math.min(days, 90)));
    Map<?, ?> ranges = (Map<?, ?>) snapshot.get().get("metricsByRange");
    Object selected = ranges.get(range);
    return read(selected == null ? snapshot.get().get("metrics") : selected);
  }

  @GET
  @Path("anomalies")
  public Response anomalies() {
    return read(snapshot.get().get("anomalies"));
  }

  @GET
  @Path("audit/{id}")
  public Response audit(@PathParam("id") String id) {
    if (id == null || !id.matches("[1-9][0-9]{0,9}"))
      return Response.status(400)
          .entity(Map.of("error", "id must be a positive issue or PR number"))
          .build();
    return read(snapshot.audit(id));
  }

  @GET
  @Path("configuration")
  public Response configuration() {
    return read(snapshot.get().get("configuration"));
  }

  @GET
  @Path("autonomous-decisions")
  public Response autonomousDecisions() {
    return read(service.autonomousDecisions());
  }

  @GET
  @Path("autonomous-decisions/issue/{id}")
  public Response autonomousDecisionsForIssue(@PathParam("id") String id) {
    if (id == null || !id.matches("[1-9][0-9]{0,9}"))
      return Response.status(400)
          .entity(Map.of("error", "id must be a positive issue number"))
          .build();
    return read(service.autonomousDecisionsForIssue(id));
  }

  @GET
  @Path("autonomous-decisions/stats")
  public Response autonomousDecisionStats() {
    return read(service.autonomousDecisionStats());
  }

  @POST
  @Path("control/{action}")
  public Response control(@PathParam("action") String action) {
    if (!controlsEnabled) {
      return Response.status(Response.Status.NOT_FOUND)
          .entity(Map.of("error", "operational controls are disabled"))
          .build();
    }
    if (!authorized(true)) return forbidden();
    if (!checkRateLimit()) return tooManyRequests();
    if (action == null || !action.matches("pause|resume|reconcile|clear-locks"))
      return Response.status(400).entity(Map.of("error", "unsupported action")).build();
    try {
      return Response.ok(service.control(action, "anonymous")).build();
    } catch (IllegalArgumentException e) {
      return Response.status(400).entity(Map.of("error", e.getMessage())).build();
    } catch (IOException e) {
      return Response.serverError()
          .entity(Map.of("error", "worker state could not be updated"))
          .build();
    }
  }

  private Response read(Object entity) {
    if (!authorized(false)) return forbidden();
    if (!checkRateLimit()) return tooManyRequests();
    return Response.ok(entity).build();
  }

  private boolean authorized(boolean manage) {
    // Public dashboard - no authentication required
    return true;
  }

  private boolean checkRateLimit() {
    // Public dashboard - no rate limiting
    return true;
  }

  private Response forbidden() {
    return Response.status(Response.Status.FORBIDDEN)
        .entity(Map.of("error", "not authorized"))
        .build();
  }

  private Response tooManyRequests() {
    return Response.status(429).entity(Map.of("error", "rate limit exceeded")).build();
  }
}
