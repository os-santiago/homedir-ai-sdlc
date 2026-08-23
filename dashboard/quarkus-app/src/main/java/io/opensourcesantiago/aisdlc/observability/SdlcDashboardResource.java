package io.opensourcesantiago.aisdlc.observability;

import io.quarkus.qute.Location;
import io.quarkus.qute.Template;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.CacheControl;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/sdlc/dashboard")
public class SdlcDashboardResource {
  @Inject
  @Location("sdlc/dashboard/index.qute.html")
  Template dashboard;

  @GET
  @Produces(MediaType.TEXT_HTML)
  public Object dashboard() {
    // Public dashboard - no authentication required
    CacheControl cc = new CacheControl();
    cc.setNoStore(true);
    return Response.ok(dashboard.instance()).cacheControl(cc).build();
  }
}
