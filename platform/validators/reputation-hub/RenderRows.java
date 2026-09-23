import io.quarkus.qute.Engine;
import io.quarkus.qute.NamespaceResolver;
import io.quarkus.qute.EvalContext;
import io.quarkus.qute.ValueResolver;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.CompletionStage;

/** Render candidate row templates with fixed data; never load application code. */
public class RenderRows {
  public static void main(String[] args) throws Exception {
    Engine engine = Engine.builder().addDefaults().strictRendering(true)
        // Expose only the initials operation used by the pilot, not reflection.
        .addValueResolver(new ValueResolver() {
          public boolean appliesTo(EvalContext context) {
            return context.getBase() instanceof String && context.getName().equals("substring")
                && context.getParams().size() == 2;
          }
          public CompletionStage<Object> resolve(EvalContext context) {
            return context.evaluate(context.getParams().get(0)).thenCombine(
                context.evaluate(context.getParams().get(1)), (start, end) -> {
                  if (!Integer.valueOf(0).equals(start) || !Integer.valueOf(1).equals(end))
                    throw new IllegalArgumentException("Unsupported initials operation");
                  return ((String) context.getBase()).substring(0, 1);
                });
          }
        })
        .addNamespaceResolver(NamespaceResolver.builder("i18n").resolve(context -> {
          return switch (context.getName()) {
            case "reputation_hub_score" -> "30 pts";
            case "reputation_hub_growth" -> "+26";
            default -> throw new IllegalArgumentException("Unsupported fixture message");
          };
        }).build()).build();
    StringBuilder html = new StringBuilder("<!doctype html><html><head></head><body><main class=\"hub-shell\"><div class=\"hub-leaderboards-grid\">");
    BufferedReader reader = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
    String line;
    int count = 0;
    while ((line = reader.readLine()) != null) {
      if (++count > 8 || line.length() > 48000) throw new IllegalArgumentException("Row limit");
      String source = new String(Base64.getDecoder().decode(line), StandardCharsets.UTF_8);
      var template = engine.parse(source);
      for (boolean linked : new boolean[] {true, false}) {
        for (String card : new String[] {"weekly", "rising"}) {
          var member = Map.of("rank", 1, "displayName", "Member", "handle", "@community_contributor_with_a_long_handle",
              "profilePath", linked ? "/member" : "", "avatarUrl", linked ? "/avatar" : "", "score", 30);
          var standing = Map.of("leader", member, "cardKey", card);
          String row = template.data("entry", member).data("standing", standing).render();
          html.append("<article class=\"hub-panel\"><ol class=\"hub-list\">").append(row).append("</ol></article>");
          if (html.length() > 512000) throw new IllegalArgumentException("Rendered output limit");
        }
      }
    }
    if (count == 0) throw new IllegalArgumentException("Rows required");
    System.out.print(html.append("</div></main></body></html>"));
  }
}
